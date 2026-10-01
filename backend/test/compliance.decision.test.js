import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateDecision, requiredKeysOf } from '../src/modules/compliance/compliance.service.js';
import { buildReviewPdf } from '../src/modules/compliance/review.pdf.js';

const REQ = ['HELMET', 'REFLECTIVE_VEST', 'SAFETY_BOOTS', 'GLOVES'];
const aiItems = (over = {}) => REQ.map((k) => ({ key: k, required: true, status: over[k] ?? 'PRESENT', confidence: 0.9, evidence: 'x', source: 'both' }));
const body = (over = {}, extra = {}) => ({ action: 'CONFIRM', items: REQ.map((k) => ({ key: k, status: over[k] ?? 'PRESENT' })), ...extra });
const run = (b, ai = aiItems(), verdict = 'COMPLIANT') => evaluateDecision({ aiItems: ai, aiVerdict: verdict, requiredKeys: REQ, body: b });
const code = (fn) => { try { fn(); return null; } catch (e) { return e.code; } };

test('CONFIRM matching the AI passes and agrees', () => {
  const r = run(body());
  assert.equal(r.finalVerdict, 'COMPLIANT');
  assert.equal(r.agreedWithAi, true);
});

test('CONFIRM with a changed item gives USE_OVERRIDE', () => {
  assert.equal(code(() => run(body({ HELMET: 'ABSENT' }))), 'USE_OVERRIDE');
});

test('CONFIRM when the AI had any UNCERTAIN gives USE_OVERRIDE', () => {
  const ai = aiItems({ GLOVES: 'UNCERTAIN' });
  assert.equal(code(() => run(body(), ai, 'NEEDS_MANUAL_REVIEW')), 'USE_OVERRIDE');
});

test('a missing key gives ITEMS_INCOMPLETE with missingKeys', () => {
  const b = body();
  b.items = b.items.filter((i) => i.key !== 'GLOVES');
  try {
    run(b);
    assert.fail('expected throw');
  } catch (e) {
    assert.equal(e.code, 'ITEMS_INCOMPLETE');
    assert.deepEqual(e.details.missingKeys, ['GLOVES']);
  }
});

test('duplicate or unknown keys are rejected too', () => {
  const dup = body();
  dup.items.push({ key: 'HELMET', status: 'PRESENT' });
  assert.equal(code(() => run(dup)), 'ITEMS_INCOMPLETE');
  const extra = body();
  extra.items.push({ key: 'SELF_RESCUER', status: 'PRESENT' });
  assert.equal(code(() => run(extra)), 'ITEMS_INCOMPLETE');
});

test('OVERRIDE needs a note of at least 10 characters', () => {
  const b = body({ HELMET: 'ABSENT' }, { action: 'OVERRIDE' });
  assert.equal(code(() => run(b)), 'VALIDATION_ERROR');
  const ok = run({ ...b, note: 'helmet missing, cap only' });
  assert.equal(ok.finalVerdict, 'NON_COMPLIANT');
  assert.equal(ok.agreedWithAi, false);
  assert.deepEqual(ok.missing, ['HELMET']);
});

test('ESCALATE needs a level and a note of at least 10 characters', () => {
  assert.equal(code(() => run(body({}, { action: 'ESCALATE', note: 'a long enough note' }))), 'VALIDATION_ERROR');
  assert.equal(code(() => run(body({}, { action: 'ESCALATE', escalationLevel: 'EMERGENCY', note: 'short' }))), 'VALIDATION_ERROR');
  assert.equal(run(body({}, { action: 'ESCALATE', escalationLevel: 'EMERGENCY', note: 'smoke seen behind worker' })).finalVerdict, 'COMPLIANT');
});

test('finalVerdict: any ABSENT -> NON_COMPLIANT, else COMPLIANT; agreedWithAi compares verdict and every item', () => {
  const ai = aiItems({ HELMET: 'ABSENT' });
  const r = run(body({ HELMET: 'ABSENT' }), ai, 'NON_COMPLIANT');
  assert.equal(r.finalVerdict, 'NON_COMPLIANT');
  assert.equal(r.agreedWithAi, true);
  const over = run(body({}, { action: 'OVERRIDE', note: 'worn under the cap, checked' }), ai, 'NON_COMPLIANT');
  assert.equal(over.finalVerdict, 'COMPLIANT');
  assert.equal(over.agreedWithAi, false);
});

test('requiredKeysOf prefers the analysed items, falls back to the zone', () => {
  assert.deepEqual(requiredKeysOf({ ai: { items: aiItems() } }, { requiredPpe: ['HELMET'] }), REQ);
  assert.deepEqual(requiredKeysOf({ ai: {} }, { requiredPpe: ['HELMET'] }), ['HELMET']);
});

test('review PDF renders a valid PDF with every section', async () => {
  const pdf = await buildReviewPdf({
    review: { _id: 'r1', ai: { overallVerdict: 'NON_COMPLIANT', overallConfidence: 0.9, criticality: { level: 'HIGH', score: 58, drivers: ['Helmet absent (0.90)'] }, emergency: { detected: false, possible: false }, items: aiItems({ HELMET: 'ABSENT' }), summary: 'Helmet absent', report: { observations: ['a'], risks: ['b'], recommendedActions: ['c'] }, conflicts: [], limitations: ['YOLO unavailable'], model: 'x', yoloProvider: 'none', latencyMs: 1200, toolTrace: [{ name: 'analyze_image_quality', calledBy: 'server' }] }, decision: { action: 'CONFIRM', finalVerdict: 'NON_COMPLIANT', items: REQ.map((k) => ({ key: k, status: k === 'HELMET' ? 'ABSENT' : 'PRESENT' })), note: '', decidedAt: new Date(), agreedWithAi: true } },
    checkIn: { capturedAt: new Date(), uploadStartedAt: new Date(), receivedAt: new Date(), clockSkewSec: 0, source: 'camera', integrityFlags: ['OFFLINE_DELAYED'] },
    worker: { fullName: 'Dinesh Oraon', employeeId: 'MIN-0105', shift: 'B' }, zone: { code: 'Z-B', name: 'Zone B' }, photo: null, deciderName: 'Sunil Banerjee',
  });
  assert.equal(pdf.subarray(0, 5).toString(), '%PDF-');
  assert.ok(pdf.length > 1500);
});
