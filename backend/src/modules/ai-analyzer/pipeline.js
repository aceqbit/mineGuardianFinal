// The analyser's side of the F2 / F3 loops: image -> review -> live events -> optional crisis request. Talks to others only via bus + sockets.
import mongoose from 'mongoose';
import { env } from '../../config/env.js';
import { audit } from '../../core/audit.js';
import { bus } from '../../core/bus.js';
import { emitTo } from '../../core/socket.js';
import { download } from '../../core/storage.js';
import { logger } from '../../core/logger.js';
import { CheckIn } from '../../models/CheckIn.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { Hazard } from '../../models/Hazard.js';
import { Zone } from '../../models/Zone.js';
import { analyzeImage } from './analyzer.js';
import { aiConfig, THRESHOLDS } from './config.js';

const config = () => aiConfig();

/** 3 or more NON_COMPLIANT decisions in the last 30 days (read from compliance_reviews). */
async function isRepeatOffender(workerId) {
  const since = new Date(Date.now() - 30 * 24 * 3600 * 1000);
  const n = await ComplianceReview.countDocuments({ workerId, status: 'DECIDED', 'decision.finalVerdict': 'NON_COMPLIANT', 'decision.decidedAt': { $gte: since } });
  return n >= 3;
}

export const predictedPayload = (review, ai, checkIn) => ({
  checkInId: String(checkIn._id),
  reviewId: String(review._id),
  workerId: String(checkIn.workerId),
  zoneId: String(checkIn.zoneId),
  verdict: ai.overallVerdict,
  overallConfidence: ai.overallConfidence,
  criticality: { level: ai.criticality.level, score: ai.criticality.score },
  summary: ai.summary,
  emergency: { detected: ai.emergency.detected, possible: ai.emergency.possible, type: ai.emergency.type },
});

/**
 * Analyse one check-in. `force` re-runs while the review is not DECIDED (supervisor "re-run").
 * Returns the review, or null when skipped.
 */
export async function processCheckIn(checkInId, { force = false } = {}) {
  const ci = await CheckIn.findById(checkInId);
  if (!ci) return null;
  if (!force && !['RECEIVED', 'ANALYZING'].includes(ci.status)) return null;
  const existing = await ComplianceReview.findOne({ checkInId: ci._id });
  if (existing?.status === 'DECIDED') return existing;

  ci.status = 'ANALYZING';
  await ci.save();
  emitTo([`user:${ci.workerId}`], 'checkin:status', { checkInId: String(ci._id), status: 'ANALYZING' });

  const zone = await Zone.findById(ci.zoneId);
  const buf = await download(ci.storagePath);
  const context = {
    zoneCode: zone?.code, requiredPpe: zone?.requiredPpe, shift: ci.shift, capturedAt: (ci.capturedAt || ci.receivedAt)?.toISOString(), source: ci.source,
    integrityFlags: ci.integrityFlags, repeatOffender: await isRepeatOffender(ci.workerId), checkInId: String(ci._id), workerId: String(ci.workerId),
  };
  const ai = await analyzeImage({ mode: 'ppe', imageBuffer: buf, context }, config());

  const dueAt = new Date(Date.now() + env.slaMinutes * 60 * 1000);
  const review = await ComplianceReview.findOneAndUpdate(
    { checkInId: ci._id, status: { $ne: 'DECIDED' } },
    {
      $set: { workerId: ci.workerId, zoneId: ci.zoneId, status: 'PENDING_REVIEW', ai },
      $setOnInsert: { sla: { dueAt, remindersSent: 0, breached: false, streakFrozen: false, compensated: false } },
    },
    { upsert: true, new: true, setDefaultsOnInsert: true },
  );

  ci.status = ai.error ? 'FAILED_AI' : 'PREDICTED';
  ci.reviewId = review._id;
  await ci.save();

  emitTo([`zone:${ci.zoneId}:supervisors`, 'role:admin', `user:${ci.workerId}`], 'compliance:predicted', predictedPayload(review, ai, ci));
  if (ai.error) emitTo([`user:${ci.workerId}`], 'checkin:status', { checkInId: String(ci._id), status: 'FAILED_AI', reason: ai.error.code });

  if (ai.emergency.detected) {
    bus.publish('CrisisRequested', {
      trigger: { type: 'ML_EMERGENCY', refId: String(review._id) },
      zoneIds: [String(ci.zoneId)],
      reason: `AI detected ${ai.emergency.type} in check-in photo`,
    });
  }
  await audit(null, 'AI_PREDICTED', 'compliance_review', review._id, { verdict: ai.overallVerdict, criticality: ai.criticality, latencyMs: ai.latencyMs, model: ai.model });
  return review;
}

export async function processHazard(hazardId) {
  const h = await Hazard.findById(hazardId);
  if (!h || h.ai) return null;
  const buf = await download(h.storagePath);
  const zone = await Zone.findById(h.zoneId);
  const ai = await analyzeImage({ mode: 'hazard', imageBuffer: buf, context: { zoneCode: zone?.code, category: h.category, capturedAt: (h.capturedAt || h.receivedAt)?.toISOString() } }, config());

  // Phase 2 writes ONLY the ai sub-document.
  h.ai = {
    severity: ai.severity, severityConfidence: ai.severityConfidence, categoryObserved: ai.categoryObserved, categoryMatches: ai.categoryMatches,
    criticality: ai.criticality, emergency: ai.emergency, summary: ai.summary, report: ai.report, model: ai.model, latencyMs: ai.latencyMs, ...(ai.error ? { error: ai.error } : {}),
  };
  await h.save();
  if (ai.error || !ai.severity) {
    logger.warn({ hazardId, error: ai.error }, 'hazard AI classification unavailable');
    return h;
  }
  emitTo([`zone:${h.zoneId}:supervisors`, 'role:admin', `user:${h.reporterId}`], 'hazard:classified', {
    hazardId: String(h._id), zoneId: String(h.zoneId), severity: ai.severity, criticality: { level: ai.criticality.level, score: ai.criticality.score }, summary: ai.summary,
    emergency: { detected: ai.emergency.detected, type: ai.emergency.type },
  });
  const critical = ai.severity === 'CRITICAL' && ai.severityConfidence >= THRESHOLDS.hazardCriticalConf;
  if (critical || ai.emergency.detected) {
    bus.publish('CrisisRequested', { trigger: { type: 'HAZARD_CRITICAL', refId: String(h._id) }, zoneIds: [String(h.zoneId)], reason: `Critical hazard: ${ai.hazardDescription || h.category}` });
  }
  await audit(null, 'AI_HAZARD_CLASSIFIED', 'hazard', h._id, { severity: ai.severity, latencyMs: ai.latencyMs });
  return h;
}

/** Restart recovery: in-memory jobs are lost when the server restarts. */
export async function findStuckWork(olderThanMs = 2 * 60 * 1000) {
  const cutoff = new Date(Date.now() - olderThanMs);
  const checkIns = await CheckIn.find({ status: { $in: ['RECEIVED', 'ANALYZING'] }, reviewId: { $exists: false }, createdAt: { $lt: cutoff } }).select('_id');
  const hazards = await Hazard.find({ ai: { $exists: false }, createdAt: { $lt: cutoff } }).select('_id');
  return { checkIns: checkIns.map((c) => String(c._id)), hazards: hazards.map((h) => String(h._id)) };
}

export const _mongoose = mongoose;
