import mongoose from 'mongoose';
import { AppError } from '../../core/errors.js';
import { audit } from '../../core/audit.js';
import { bus } from '../../core/bus.js';
import { emitTo } from '../../core/socket.js';
import { download, signedUrl, uploadBuffer } from '../../core/storage.js';
import { isZoneStaff } from '../../core/auth.js';
import { CheckIn } from '../../models/CheckIn.js';
import { ComplianceReview } from '../../models/ComplianceReview.js';
import { User } from '../../models/User.js';
import { Zone } from '../../models/Zone.js';
import { buildReviewPdf } from './review.pdf.js';

const MIN_NOTE = 10;

/** Required PPE keys as analysed (the AI items are authoritative at analysis time). */
export const requiredKeysOf = (review, zone) => {
  const fromAi = (review.ai?.items ?? []).filter((i) => i.required).map((i) => i.key);
  return fromAi.length ? fromAi : [...(zone?.requiredPpe ?? [])];
};

/**
 * Pure decision rules. Returns { finalVerdict, agreedWithAi } or throws AppError.
 * - items must contain EXACTLY every required key once (400 ITEMS_INCOMPLETE { missingKeys })
 * - UNCERTAIN is not allowed (zod rejects it before this runs)
 * - CONFIRM only when every item equals the AI status; any AI UNCERTAIN, or any difference, gives 400 USE_OVERRIDE
 * - OVERRIDE needs a note >= 10 characters; ESCALATE needs escalationLevel and a note >= 10 characters
 */
export function evaluateDecision({ aiItems, aiVerdict, requiredKeys, body }) {
  const provided = new Map();
  const dup = [];
  for (const it of body.items) {
    if (provided.has(it.key)) dup.push(it.key);
    provided.set(it.key, it.status);
  }
  const missingKeys = requiredKeys.filter((k) => !provided.has(k));
  const extraKeys = [...provided.keys()].filter((k) => !requiredKeys.includes(k));
  if (missingKeys.length || extraKeys.length || dup.length) {
    throw new AppError(400, 'ITEMS_INCOMPLETE', 'Decide every required checklist item exactly once', { missingKeys, extraKeys, duplicateKeys: dup });
  }
  const aiStatus = new Map(aiItems.filter((i) => i.required).map((i) => [i.key, i.status]));
  const anyUncertain = [...aiStatus.values()].includes('UNCERTAIN');
  const differs = requiredKeys.some((k) => aiStatus.get(k) !== provided.get(k));
  const note = (body.note ?? '').trim();

  if (body.action === 'CONFIRM') {
    if (anyUncertain || differs) throw new AppError(400, 'USE_OVERRIDE', 'This does not match the AI result. Use Override and add a note');
  } else if (body.action === 'OVERRIDE') {
    if (note.length < MIN_NOTE) throw new AppError(400, 'VALIDATION_ERROR', `A note of at least ${MIN_NOTE} characters is required to override`, [{ path: 'note', message: 'Too short' }]);
  } else if (body.action === 'ESCALATE') {
    if (!body.escalationLevel) throw new AppError(400, 'VALIDATION_ERROR', 'escalationLevel is required to escalate', [{ path: 'escalationLevel', message: 'Required' }]);
    if (note.length < MIN_NOTE) throw new AppError(400, 'VALIDATION_ERROR', `A note of at least ${MIN_NOTE} characters is required to escalate`, [{ path: 'note', message: 'Too short' }]);
  }
  const finalVerdict = [...provided.values()].includes('ABSENT') ? 'NON_COMPLIANT' : 'COMPLIANT';
  const agreedWithAi = finalVerdict === aiVerdict && !differs;
  return { finalVerdict, agreedWithAi, missing: [...provided.entries()].filter(([, s]) => s === 'ABSENT').map(([k]) => k) };
}

async function loadReviewFor(user, filter) {
  const review = await ComplianceReview.findOne(filter);
  if (!review) throw new AppError(404, 'NOT_FOUND', 'Review not found');
  if (!isZoneStaff(user, review.zoneId)) throw new AppError(403, 'FORBIDDEN_ROLE', 'Not your zone');
  return review;
}

export async function getReviewByCheckIn(user, checkInId) {
  const review = await loadReviewFor(user, { checkInId });
  const [checkIn, worker, zone] = await Promise.all([CheckIn.findById(checkInId), User.findById(review.workerId), Zone.findById(review.zoneId)]);
  const recent = await ComplianceReview.find({ workerId: review.workerId, status: 'DECIDED', _id: { $ne: review._id } }).sort({ 'decision.decidedAt': -1 }).limit(5);
  const co = checkIn.toJSON();
  co.imageUrl = await signedUrl(checkIn.storagePath).catch(() => null);
  return {
    review: review.toJSON(),
    checkIn: co,
    worker: worker && { id: String(worker._id), fullName: worker.fullName, employeeId: worker.employeeId, shift: worker.shift },
    zone: zone && { id: String(zone._id), code: zone.code, name: zone.name, requiredPpe: zone.requiredPpe },
    recentDecisions: recent.map((r) => ({
      date: r.decision?.decidedAt, finalVerdict: r.decision?.finalVerdict, missing: (r.decision?.items ?? []).filter((i) => i.status === 'ABSENT').map((i) => i.key),
    })),
  };
}

export async function decide(user, reviewId, body) {
  const review = await loadReviewFor(user, { _id: reviewId });
  const redecide = review.status === 'DECIDED';
  if (redecide && user.role !== 'admin') throw new AppError(409, 'ALREADY_DECIDED', 'This review has already been decided');
  if (redecide && (body.note ?? '').trim().length < MIN_NOTE) throw new AppError(400, 'VALIDATION_ERROR', 'A note is required to re-decide a review', [{ path: 'note', message: 'Too short' }]);
  const zone = await Zone.findById(review.zoneId);
  const requiredKeys = requiredKeysOf(review, zone);
  const { finalVerdict, agreedWithAi, missing } = evaluateDecision({ aiItems: review.ai?.items ?? [], aiVerdict: review.ai?.overallVerdict, requiredKeys, body });

  const decision = {
    action: body.action,
    ...(body.escalationLevel ? { escalationLevel: body.escalationLevel } : {}),
    finalVerdict,
    items: body.items.map((i) => ({ key: i.key, status: i.status })),
    note: (body.note ?? '').trim(),
    decidedBy: user._id,
    decidedAt: new Date(),
    agreedWithAi,
  };
  review.decision = decision;
  review.status = 'DECIDED';
  review.markModified('decision');
  await review.save();
  await CheckIn.updateOne({ _id: review.checkInId }, { $set: { status: 'REVIEWED' } });

  if (body.action === 'ESCALATE' && body.escalationLevel === 'EMERGENCY') {
    bus.publish('CrisisRequested', { trigger: { type: 'SUPERVISOR_ESCALATION', refId: String(review._id), by: String(user._id) }, zoneIds: [String(review.zoneId)], reason: decision.note });
  }
  emitTo([`user:${review.workerId}`, `zone:${review.zoneId}:supervisors`, 'role:admin'], 'compliance:reviewed', {
    checkInId: String(review.checkInId), reviewId: String(review._id), workerId: String(review.workerId), finalVerdict, missing, decidedBy: user.fullName, action: body.action,
  });
  bus.publish('ComplianceReviewed', { reviewId: String(review._id), workerId: String(review.workerId), finalVerdict });
  await audit(user, 'REVIEW_DECIDED', 'compliance_review', review._id, { action: body.action, finalVerdict, agreedWithAi, redecide });
  return review.toJSON();
}

export async function reviewReportUrl(user, reviewId) {
  const review = await loadReviewFor(user, { _id: reviewId });
  const [checkIn, worker, zone] = await Promise.all([CheckIn.findById(review.checkInId), User.findById(review.workerId), Zone.findById(review.zoneId)]);
  let photo = null;
  try {
    photo = await download(checkIn.storagePath);
  } catch {
    /* the PDF is still useful without the photo */
  }
  const decider = review.decision?.decidedBy ? await User.findById(review.decision.decidedBy).select('fullName') : null;
  const pdf = await buildReviewPdf({ review: review.toJSON(), checkIn: checkIn.toJSON(), worker, zone, photo, deciderName: decider?.fullName });
  const path = `reports/review-${review._id}.pdf`;
  await uploadBuffer(path, pdf, 'application/pdf');
  return { url: await signedUrl(path, 15) };
}

export const isId = (v) => mongoose.isValidObjectId(v);
