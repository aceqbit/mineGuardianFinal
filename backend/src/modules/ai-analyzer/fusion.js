// Deterministic fusion of Gemini's item results with YOLO detections. Pure; runs after Stage B and before the verdict.
import { THRESHOLDS } from './config.js';
import { PPE_LABEL } from './config.js';

const r2 = (n) => Math.round(n * 100) / 100;
const cap = (n) => Math.min(THRESHOLDS.maxItemConfidence, n);

/** Fraction of box `a` (the detection) that lies inside box `b`. Boxes are {x,y,w,h} normalised. */
export function overlapOfOwnArea(a, b) {
  const x1 = Math.max(a.x, b.x), y1 = Math.max(a.y, b.y), x2 = Math.min(a.x + a.w, b.x + b.w), y2 = Math.min(a.y + a.h, b.y + b.h);
  const inter = Math.max(0, x2 - x1) * Math.max(0, y2 - y1);
  const area = a.w * a.h;
  return area <= 0 ? 0 : inter / area;
}

function evidenceFor(yolo, key, polarity) {
  const person = yolo.mainPersonBox;
  let best = 0;
  for (const d of yolo.detections ?? []) {
    if (d.ppeKey !== key || d.polarity !== polarity) continue;
    if (person && overlapOfOwnArea(d.box, person) < 0.3) continue; // belongs to someone else
    best = Math.max(best, d.confidence);
  }
  return best;
}

/**
 * fuse(items, { yolo, imageQuality }) -> { items, conflicts, limitations }.
 * Rules, first match wins, applied per REQUIRED item g with pos / neg = best matching YOLO confidence:
 *  a  YOLO unavailable                          keep g, conf = min(g, 0.85), source gemini
 *  b  key not detectable by the model           keep g, conf = min(g, 0.90), source gemini
 *  c  g PRESENT and pos >= 0.50                 PRESENT, conf = min(0.99, max(g, pos) + 0.05), source both
 *  d  g ABSENT and (neg >= 0.50 or pos < 0.25)  ABSENT, conf = min(0.99, max(g, neg)), source both
 *  e  g PRESENT and neg >= 0.60                 UNCERTAIN 0.50 + conflict
 *  f  g ABSENT and pos >= 0.60                  UNCERTAIN 0.50 + conflict
 *  g  g UNCERTAIN and (pos >= 0.80 with image quality ok, or neg >= 0.80)   PRESENT at pos - 0.10 or ABSENT at neg - 0.10, source yolo
 *  h  anything else                             keep g
 */
export function fuse(items, { yolo = null, imageQuality = null } = {}) {
  const conflicts = [];
  const limitations = [];
  const unavailable = !yolo || yolo.status !== 'ok';
  if (unavailable) limitations.push('YOLO unavailable');
  const detectable = new Set(yolo?.detectableKeys ?? []);
  const qualityOk = (imageQuality?.verdict ?? 'ok') === 'ok';

  const out = items.map((g) => {
    if (!g.required) return g;
    if (unavailable) return { ...g, confidence: r2(Math.min(g.confidence, THRESHOLDS.confCapNoYolo)), source: 'gemini' }; // a
    if (!detectable.has(g.key)) return { ...g, confidence: r2(Math.min(g.confidence, THRESHOLDS.confCapNotDetectable)), source: 'gemini' }; // b
    const pos = evidenceFor(yolo, g.key, '+');
    const neg = evidenceFor(yolo, g.key, '-');
    const label = PPE_LABEL[g.key] ?? g.key;
    if (g.status === 'PRESENT' && pos >= THRESHOLDS.yoloPositive) return { ...g, confidence: r2(cap(Math.max(g.confidence, pos) + 0.05)), source: 'both' }; // c
    if (g.status === 'ABSENT' && (neg >= THRESHOLDS.yoloPositive || pos < 0.25)) return { ...g, confidence: r2(cap(Math.max(g.confidence, neg))), source: 'both' }; // d
    if (g.status === 'PRESENT' && neg >= 0.6) { // e
      conflicts.push(`${label}: Gemini saw it PRESENT but YOLO detected "no ${label.toLowerCase()}" (${neg.toFixed(2)})`);
      return { ...g, status: 'UNCERTAIN', confidence: 0.5, source: 'both' };
    }
    if (g.status === 'ABSENT' && pos >= 0.6) { // f
      conflicts.push(`${label}: Gemini saw it ABSENT but YOLO detected it (${pos.toFixed(2)})`);
      return { ...g, status: 'UNCERTAIN', confidence: 0.5, source: 'both' };
    }
    if (g.status === 'UNCERTAIN') { // g
      if (pos >= THRESHOLDS.yoloStrong && qualityOk) return { ...g, status: 'PRESENT', confidence: r2(pos - 0.1), evidence: g.evidence || `YOLO detected ${label.toLowerCase()} (${pos.toFixed(2)})`, source: 'yolo' };
      if (neg >= THRESHOLDS.yoloStrong) return { ...g, status: 'ABSENT', confidence: r2(neg - 0.1), evidence: g.evidence || `YOLO detected no ${label.toLowerCase()} (${neg.toFixed(2)})`, source: 'yolo' };
    }
    return g; // h
  });
  return { items: out, conflicts, limitations };
}

/** ML_MODE=yolo_only (no Gemini key): YOLO decides detectable keys; everything else is UNCERTAIN. */
export function yoloOnlyRaw(required, yolo) {
  const ok = yolo && yolo.status === 'ok';
  const detectable = new Set(yolo?.detectableKeys ?? []);
  const items = required.map((key) => {
    if (!ok || !detectable.has(key)) return { key, status: 'UNCERTAIN', confidence: 0.3, evidence: '' };
    const pos = evidenceFor(yolo, key, '+');
    const neg = evidenceFor(yolo, key, '-');
    if (pos >= THRESHOLDS.yoloPositive && pos >= neg) return { key, status: 'PRESENT', confidence: r2(cap(pos)), evidence: `YOLO detected ${(PPE_LABEL[key] ?? key).toLowerCase()} (${pos.toFixed(2)})` };
    if (neg >= THRESHOLDS.yoloPositive) return { key, status: 'ABSENT', confidence: r2(cap(neg)), evidence: `YOLO detected no ${(PPE_LABEL[key] ?? key).toLowerCase()} (${neg.toFixed(2)})` };
    return { key, status: 'UNCERTAIN', confidence: 0.4, evidence: '' };
  });
  const box = yolo?.mainPersonBox;
  return {
    mode: 'PPE_COMPLIANCE', image_relevance: ok ? 'RELEVANT' : 'RELEVANT', framing: { full_body_visible: !!box && box.h >= 0.55, persons_count: yolo?.personCount ?? 0, notes: 'YOLO only' },
    items, emergency: { detected: false, possible: false, type: 'NONE', confidence: 0, evidence: '' }, conflicts: [], limitations: ['Gemini not used (yolo_only mode)'],
    summary: 'Assessed from YOLO detections only.', report: { observations: ['YOLO-only analysis'], risks: [], recommended_actions: ['Supervisor to review'] },
  };
}
