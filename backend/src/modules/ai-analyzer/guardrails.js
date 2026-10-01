// Deterministic guardrails: the SERVER decides the verdict from the model's evidence. Pure functions, unit-tested.
import { PPE_KEY } from '../../contracts/enums.js';
import {
  THRESHOLDS, PPE_WEIGHTS, PPE_LABEL, HAZARD_BASE_SCORE, REPEAT_OFFENDER_BONUS, INTEGRITY_BONUS, INTEGRITY_BONUS_FLAGS, levelFor,
} from './config.js';

const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v));
const round2 = (n) => Math.round(n * 100) / 100;

export const VERDICT_LABEL = { COMPLIANT: 'Compliant', NON_COMPLIANT: 'Non-compliant', NEEDS_MANUAL_REVIEW: 'Needs manual review' };

/**
 * One final item per PPE key.
 * - required key the model omitted -> UNCERTAIN 0.3 "not assessed by model"
 * - non-required key -> NOT_REQUIRED (observed status kept in evidence)
 * - required item below minItemConfidence -> UNCERTAIN; PRESENT/ABSENT with empty evidence -> UNCERTAIN
 * - confidence clamped to 0..0.99
 */
export function normalizeItems(rawItems, required) {
  const byKey = new Map();
  for (const it of rawItems ?? []) if (it && PPE_KEY.includes(it.key) && !byKey.has(it.key)) byKey.set(it.key, it);
  return PPE_KEY.map((key) => {
    const isRequired = required.includes(key);
    const m = byKey.get(key);
    if (!isRequired) {
      const observed = m ? `${m.status} (${m.evidence || 'no evidence'})` : 'not assessed';
      return { key, required: false, status: 'NOT_REQUIRED', confidence: 0, evidence: `Not required in this zone. Observed: ${observed}`, region: null, source: 'gemini' };
    }
    if (!m) return { key, required: true, status: 'UNCERTAIN', confidence: 0.3, evidence: 'not assessed by model', region: null, source: 'gemini' };
    let status = m.status;
    const confidence = round2(clamp(Number(m.confidence) || 0, 0, THRESHOLDS.maxItemConfidence));
    const evidence = (m.evidence ?? '').trim();
    if (confidence < THRESHOLDS.minItemConfidence) status = 'UNCERTAIN';
    if ((status === 'PRESENT' || status === 'ABSENT') && !evidence) status = 'UNCERTAIN';
    return { key, required: true, status, confidence, evidence, region: m.region ?? null, source: 'gemini' };
  });
}

/** IRRELEVANT images make every required item UNCERTAIN. */
export function applyRelevance(items, relevance) {
  if (relevance !== 'IRRELEVANT') return items;
  return items.map((i) => (i.required ? { ...i, status: 'UNCERTAIN', confidence: Math.min(i.confidence, 0.3), evidence: i.evidence || 'image is not a genuine photo' } : i));
}

/** Any required ABSENT -> NON_COMPLIANT; else any required UNCERTAIN / body not fully visible / poor quality -> NEEDS_MANUAL_REVIEW; else COMPLIANT. */
export function computeVerdict(items, { fullBodyVisible = true, imageQuality = 'ok' } = {}) {
  const req = items.filter((i) => i.required);
  if (req.some((i) => i.status === 'ABSENT')) return 'NON_COMPLIANT';
  if (req.some((i) => i.status === 'UNCERTAIN') || !fullBodyVisible || imageQuality === 'poor') return 'NEEDS_MANUAL_REVIEW';
  return 'COMPLIANT';
}

/** Weakest link for COMPLIANT / NEEDS_MANUAL_REVIEW; strongest ABSENT for NON_COMPLIANT. */
export function computeOverallConfidence(items, verdict) {
  const req = items.filter((i) => i.required);
  if (!req.length) return 0;
  if (verdict === 'NON_COMPLIANT') return round2(Math.max(...req.filter((i) => i.status === 'ABSENT').map((i) => i.confidence)));
  return round2(Math.min(...req.map((i) => i.confidence)));
}

/**
 * detected stays true only at confidence >= 0.80. 0.50..0.80 becomes detected=false, possible=true.
 * A YOLO fall detection >= 0.70 makes possible true but never detected on YOLO alone.
 */
export function emergencyGate(emergency, { yoloFall } = {}) {
  const e = { detected: false, possible: false, type: 'NONE', confidence: 0, evidence: '', ...(emergency ?? {}) };
  e.confidence = round2(clamp(Number(e.confidence) || 0, 0, THRESHOLDS.maxItemConfidence));
  const claimed = e.detected === true;
  if (claimed && e.confidence >= THRESHOLDS.emergencyDetectConf) {
    e.detected = true;
    e.possible = true;
  } else if (claimed && e.confidence >= THRESHOLDS.emergencyPossibleConf) {
    e.detected = false;
    e.possible = true;
  } else {
    e.detected = false;
    e.possible = e.possible === true && e.confidence >= THRESHOLDS.emergencyPossibleConf ? true : claimed ? false : e.possible === true;
  }
  if (yoloFall && yoloFall.value && yoloFall.confidence >= THRESHOLDS.yoloFallPossible) {
    e.possible = true;
    if (e.type === 'NONE') e.type = 'INJURED_PERSON';
    if (!e.evidence) e.evidence = 'YOLO fall detection';
  }
  if (!e.detected && !e.possible) e.type = 'NONE';
  return e;
}

/**
 * Criticality for a shift photo.
 * Score = sum(required ABSENT: weight x confidence) + sum(required UNCERTAIN: weight x 0.5)
 *         + 10 repeat offender + 15 if integrity flags include DUPLICATE_HASH / STALE_PHOTO / OUTSIDE_ZONE. A detected emergency forces 100.
 */
export function computeCriticality(items, { repeatOffender = false, integrityFlags = [], emergencyDetected = false, ageAtUploadMin = null } = {}) {
  const drivers = [];
  let score = 0;
  for (const i of items.filter((x) => x.required)) {
    const w = PPE_WEIGHTS[i.key] ?? 0;
    if (i.status === 'ABSENT') {
      score += w * i.confidence;
      drivers.push({ pts: w * i.confidence, text: `${PPE_LABEL[i.key]} absent (${i.confidence.toFixed(2)})` });
    } else if (i.status === 'UNCERTAIN') {
      score += w * 0.5;
      drivers.push({ pts: w * 0.5, text: `${PPE_LABEL[i.key]} uncertain` });
    }
  }
  if (repeatOffender) {
    score += REPEAT_OFFENDER_BONUS;
    drivers.push({ pts: REPEAT_OFFENDER_BONUS, text: 'Repeat offender (3+ non-compliant in 30 days)' });
  }
  const flagged = integrityFlags.filter((f) => INTEGRITY_BONUS_FLAGS.includes(f));
  if (flagged.length) {
    score += INTEGRITY_BONUS;
    const age = flagged.includes('STALE_PHOTO') && ageAtUploadMin != null ? `Photo taken ${Math.round(ageAtUploadMin)} min before upload` : `Integrity: ${flagged.join(', ')}`;
    drivers.push({ pts: INTEGRITY_BONUS, text: age });
  }
  if (emergencyDetected) {
    score = 100;
    drivers.unshift({ pts: 100, text: 'Emergency detected in the scene' });
  }
  const final = Math.round(clamp(score, 0, 100));
  return { level: levelFor(final), score: final, drivers: drivers.sort((a, b) => b.pts - a.pts).map((d) => d.text) };
}

/** Hazard guard: a detected emergency forces CRITICAL; IRRELEVANT forces LOW. Criticality = base x (0.7 + 0.3 x severityConfidence). */
export function hazardGuard(h, emergency) {
  const limitations = [...(h.limitations ?? [])];
  let severity = h.severity;
  let severityConfidence = round2(clamp(Number(h.severity_confidence) || 0, 0, THRESHOLDS.maxItemConfidence));
  if (emergency.detected) severity = 'CRITICAL';
  if (h.image_relevance === 'IRRELEVANT') {
    severity = 'LOW';
    severityConfidence = Math.min(severityConfidence, 0.5);
    limitations.push('Image is not a genuine photo of a hazard scene');
  }
  const score = Math.round(clamp(HAZARD_BASE_SCORE[severity] * (0.7 + 0.3 * severityConfidence), 0, 100));
  const finalScore = emergency.detected ? Math.max(score, 90) : score;
  return {
    severity,
    severityConfidence,
    limitations,
    criticality: { level: levelFor(finalScore), score: finalScore, drivers: [`${severity} severity (${severityConfidence.toFixed(2)})`, ...(emergency.detected ? ['Emergency detected in the scene'] : [])] },
  };
}

/** "<Verdict label> · <LEVEL> <score>/100 — <model summary>", at most 300 characters. */
export function composeSummary(verdict, criticality, modelSummary) {
  const head = `${VERDICT_LABEL[verdict] ?? verdict} · ${criticality.level} ${criticality.score}/100`;
  const s = (modelSummary ?? '').trim();
  const full = s ? `${head} — ${s}` : head;
  return full.length <= 300 ? full : `${full.slice(0, 297)}...`;
}
