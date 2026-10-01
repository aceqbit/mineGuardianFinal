import test from 'node:test';
import assert from 'node:assert/strict';
import { fuse, overlapOfOwnArea, yoloOnlyRaw } from '../src/modules/ai-analyzer/fusion.js';
import { computeMetrics, percentile, meetsTargets } from '../src/modules/ai-analyzer/eval/metrics.js';

const g = (key, status, confidence, evidence = 'seen') => ({ key, required: true, status, confidence, evidence, source: 'gemini' });
const person = { x: 0.2, y: 0.05, w: 0.6, h: 0.9 };
const det = (ppeKey, polarity, confidence, box = { x: 0.35, y: 0.08, w: 0.15, h: 0.1 }) => ({ label: 'x', ppeKey, polarity, confidence, box });
const yolo = (detections, extra = {}) => ({ status: 'ok', provider: 'roboflow', detections, personCount: 1, mainPersonBox: person, fallDetected: { value: false, confidence: 0 }, detectableKeys: ['HELMET', 'REFLECTIVE_VEST', 'GLOVES'], ...extra });
const one = (item, y, q) => fuse([item], { yolo: y, imageQuality: q });

test('rule a: YOLO unavailable keeps g, caps confidence at 0.85, notes the limitation', () => {
  const r = one(g('HELMET', 'PRESENT', 0.97), { status: 'unavailable' });
  assert.equal(r.items[0].confidence, 0.85);
  assert.equal(r.items[0].source, 'gemini');
  assert.deepEqual(r.limitations, ['YOLO unavailable']);
});

test('rule b: a key the model cannot detect is capped at 0.90', () => {
  const r = one(g('SAFETY_BOOTS', 'PRESENT', 0.97), yolo([]));
  assert.equal(r.items[0].confidence, 0.9);
  assert.equal(r.items[0].source, 'gemini');
});

test('rule c: PRESENT + YOLO positive >= 0.50 -> PRESENT, max+0.05, source both', () => {
  const r = one(g('HELMET', 'PRESENT', 0.8), yolo([det('HELMET', '+', 0.9)]));
  assert.equal(r.items[0].status, 'PRESENT');
  assert.equal(r.items[0].confidence, 0.95);
  assert.equal(r.items[0].source, 'both');
  assert.equal(one(g('HELMET', 'PRESENT', 0.97), yolo([det('HELMET', '+', 0.9)])).items[0].confidence, 0.99); // capped
});

test('rule d: ABSENT + YOLO negative >= 0.50, or no positive evidence -> ABSENT, source both', () => {
  const a = one(g('HELMET', 'ABSENT', 0.8), yolo([det('HELMET', '-', 0.7)]));
  assert.equal(a.items[0].status, 'ABSENT');
  assert.equal(a.items[0].confidence, 0.8);
  assert.equal(a.items[0].source, 'both');
  const b = one(g('HELMET', 'ABSENT', 0.8), yolo([]));
  assert.equal(b.items[0].status, 'ABSENT');
  assert.equal(b.items[0].source, 'both');
});

test('rule e: PRESENT but YOLO sees "no helmet" at >= 0.60 and no positive -> UNCERTAIN 0.50 + conflict', () => {
  const r = one(g('HELMET', 'PRESENT', 0.9), yolo([det('HELMET', '-', 0.72)]));
  assert.equal(r.items[0].status, 'UNCERTAIN');
  assert.equal(r.items[0].confidence, 0.5);
  assert.equal(r.conflicts.length, 1);
});

test('rule f: ABSENT but YOLO sees it at >= 0.60 -> UNCERTAIN 0.50 + conflict', () => {
  const r = one(g('GLOVES', 'ABSENT', 0.9), yolo([det('GLOVES', '+', 0.65)]));
  assert.equal(r.items[0].status, 'UNCERTAIN');
  assert.equal(r.conflicts.length, 1);
});

test('rule g: UNCERTAIN promoted by strong YOLO (quality ok) or strong negative', () => {
  const p = one(g('HELMET', 'UNCERTAIN', 0.4, ''), yolo([det('HELMET', '+', 0.9)]), { verdict: 'ok' });
  assert.equal(p.items[0].status, 'PRESENT');
  assert.equal(p.items[0].confidence, 0.8);
  assert.equal(p.items[0].source, 'yolo');
  const poor = one(g('HELMET', 'UNCERTAIN', 0.4, ''), yolo([det('HELMET', '+', 0.9)]), { verdict: 'poor' });
  assert.equal(poor.items[0].status, 'UNCERTAIN');
  const n = one(g('HELMET', 'UNCERTAIN', 0.4, ''), yolo([det('HELMET', '-', 0.85)]), { verdict: 'poor' });
  assert.equal(n.items[0].status, 'ABSENT');
  assert.equal(n.items[0].confidence, 0.75);
});

test('rule h: anything else is kept', () => {
  const r = one(g('HELMET', 'PRESENT', 0.8), yolo([det('HELMET', '+', 0.3)]));
  assert.equal(r.items[0].status, 'PRESENT');
  assert.equal(r.items[0].confidence, 0.8);
});

test('detections that belong to another person (outside the main box) are ignored', () => {
  const far = det('HELMET', '+', 0.95, { x: 0.85, y: 0.1, w: 0.1, h: 0.1 });
  assert.equal(overlapOfOwnArea(far.box, person), 0);
  const r = one(g('HELMET', 'ABSENT', 0.8), yolo([far]));
  assert.equal(r.items[0].status, 'ABSENT'); // the background worker's helmet does not count
});

test('non-required items pass through untouched', () => {
  const item = { key: 'SELF_RESCUER', required: false, status: 'NOT_REQUIRED', confidence: 0, evidence: '', source: 'gemini' };
  assert.deepEqual(fuse([item], { yolo: yolo([]) }).items[0], item);
});

test('yolo_only: detectable keys decided from YOLO, everything else UNCERTAIN', () => {
  const raw = yoloOnlyRaw(['HELMET', 'SAFETY_BOOTS', 'GLOVES'], yolo([det('HELMET', '+', 0.9), det('GLOVES', '-', 0.8)]));
  const by = Object.fromEntries(raw.items.map((i) => [i.key, i]));
  assert.equal(by.HELMET.status, 'PRESENT');
  assert.equal(by.GLOVES.status, 'ABSENT');
  assert.equal(by.SAFETY_BOOTS.status, 'UNCERTAIN');
  assert.equal(raw.framing.full_body_visible, true);
});

test('eval metrics', () => {
  const labels = [
    { file: 'a', mode: 'PPE_COMPLIANCE', expected: { verdict: 'COMPLIANT', items: { HELMET: 'PRESENT' } } },
    { file: 'b', mode: 'PPE_COMPLIANCE', expected: { verdict: 'NON_COMPLIANT', items: { HELMET: 'ABSENT' } } },
    { file: 'c', mode: 'PPE_COMPLIANCE', expected: { notVerdicts: ['COMPLIANT'], relevance: 'IRRELEVANT' } },
  ];
  const r = (v, helmet, relevance = 'RELEVANT', emergency = false) => ({ overallVerdict: v, imageRelevance: relevance, items: [{ key: 'HELMET', required: true, status: helmet }], emergency: { detected: emergency }, latencyMs: 1000 });
  const m = computeMetrics(labels, [r('COMPLIANT', 'PRESENT'), r('NON_COMPLIANT', 'ABSENT'), r('NEEDS_MANUAL_REVIEW', 'UNCERTAIN', 'IRRELEVANT')]);
  assert.equal(m.verdictAccuracy, 100);
  assert.equal(m.absentRecall, 100);
  assert.equal(m.adversarial.unsafe.length, 0);
  assert.equal(m.falseEmergencies, 0);
  assert.equal(Object.values(meetsTargets(m)).every(Boolean), true);
  const bad = computeMetrics(labels, [r('COMPLIANT', 'PRESENT'), r('COMPLIANT', 'PRESENT'), r('COMPLIANT', 'PRESENT', 'RELEVANT', true)]);
  assert.equal(bad.absentRecall, 0);
  assert.equal(bad.adversarial.unsafe.length, 1);
  assert.equal(bad.falseEmergencies, 1);
  assert.equal(percentile([1, 2, 3, 4, 100], 95), 100);
});
