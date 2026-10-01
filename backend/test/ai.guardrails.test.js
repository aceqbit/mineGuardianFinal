import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizeItems, applyRelevance, computeVerdict, computeOverallConfidence, emergencyGate, computeCriticality, hazardGuard, composeSummary } from '../src/modules/ai-analyzer/guardrails.js';
import { DEFAULT_REQUIRED_PPE, levelFor } from '../src/modules/ai-analyzer/config.js';

const REQ = [...DEFAULT_REQUIRED_PPE];
const item = (key, status, confidence, evidence = 'visible on head') => ({ key, status, confidence, evidence });
const allPresent = () => REQ.map((k) => item(k, 'PRESENT', 0.9));

test('a required ABSENT gives NON_COMPLIANT', () => {
  const raw = allPresent().map((i) => (i.key === 'HELMET' ? item('HELMET', 'ABSENT', 0.92, 'bare head') : i));
  const items = normalizeItems(raw, REQ);
  assert.equal(computeVerdict(items), 'NON_COMPLIANT');
});

test('a required UNCERTAIN gives NEEDS_MANUAL_REVIEW', () => {
  const raw = allPresent().map((i) => (i.key === 'GLOVES' ? item('GLOVES', 'UNCERTAIN', 0.5) : i));
  assert.equal(computeVerdict(normalizeItems(raw, REQ)), 'NEEDS_MANUAL_REVIEW');
});

test('a low-confidence PRESENT becomes UNCERTAIN', () => {
  const raw = allPresent().map((i) => (i.key === 'HELMET' ? item('HELMET', 'PRESENT', 0.55) : i));
  const items = normalizeItems(raw, REQ);
  assert.equal(items.find((i) => i.key === 'HELMET').status, 'UNCERTAIN');
});

test('PRESENT / ABSENT without evidence becomes UNCERTAIN', () => {
  const raw = allPresent().map((i) => (i.key === 'GLOVES' ? item('GLOVES', 'PRESENT', 0.9, '   ') : i));
  assert.equal(normalizeItems(raw, REQ).find((i) => i.key === 'GLOVES').status, 'UNCERTAIN');
});

test('omitted required key -> UNCERTAIN 0.3; non-required key -> NOT_REQUIRED; one item per PPE key', () => {
  const items = normalizeItems(allPresent().filter((i) => i.key !== 'GLOVES'), REQ);
  assert.equal(items.length, 10);
  const g = items.find((i) => i.key === 'GLOVES');
  assert.equal(g.status, 'UNCERTAIN');
  assert.equal(g.confidence, 0.3);
  assert.equal(g.evidence, 'not assessed by model');
  assert.equal(items.find((i) => i.key === 'SELF_RESCUER').status, 'NOT_REQUIRED');
});

test('confidence is clamped to 0.99', () => {
  const items = normalizeItems([item('HELMET', 'PRESENT', 1)], ['HELMET']);
  assert.equal(items.find((i) => i.key === 'HELMET').confidence, 0.99);
});

test('IRRELEVANT gives NEEDS_MANUAL_REVIEW', () => {
  const items = applyRelevance(normalizeItems(allPresent(), REQ), 'IRRELEVANT');
  assert.ok(items.filter((i) => i.required).every((i) => i.status === 'UNCERTAIN'));
  assert.equal(computeVerdict(items), 'NEEDS_MANUAL_REVIEW');
});

test('full_body_visible=false or poor image quality gives NEEDS_MANUAL_REVIEW even when all present', () => {
  const items = normalizeItems(allPresent(), REQ);
  assert.equal(computeVerdict(items, { fullBodyVisible: false }), 'NEEDS_MANUAL_REVIEW');
  assert.equal(computeVerdict(items, { imageQuality: 'poor' }), 'NEEDS_MANUAL_REVIEW');
  assert.equal(computeVerdict(items), 'COMPLIANT');
});

test('overall confidence: weakest link / strongest ABSENT', () => {
  const ok = normalizeItems([item('HELMET', 'PRESENT', 0.95), item('REFLECTIVE_VEST', 'PRESENT', 0.7), item('SAFETY_BOOTS', 'PRESENT', 0.88), item('GLOVES', 'PRESENT', 0.9)], REQ);
  assert.equal(computeOverallConfidence(ok, 'COMPLIANT'), 0.7);
  const bad = normalizeItems([item('HELMET', 'ABSENT', 0.92), item('GLOVES', 'ABSENT', 0.7), item('REFLECTIVE_VEST', 'PRESENT', 0.9), item('SAFETY_BOOTS', 'PRESENT', 0.9)], REQ);
  assert.equal(computeOverallConfidence(bad, 'NON_COMPLIANT'), 0.92);
});

test('an emergency at 0.7 is possible, not detected; at 0.85 detected', () => {
  const e = emergencyGate({ detected: true, possible: true, type: 'FIRE', confidence: 0.7, evidence: 'flames' });
  assert.equal(e.detected, false);
  assert.equal(e.possible, true);
  const d = emergencyGate({ detected: true, possible: true, type: 'FIRE', confidence: 0.85, evidence: 'flames' });
  assert.equal(d.detected, true);
  const none = emergencyGate({ detected: false, possible: false, type: 'NONE', confidence: 0 });
  assert.equal(none.detected, false);
  assert.equal(none.possible, false);
});

test('YOLO fall >= 0.70 makes possible true but never detected on YOLO alone', () => {
  const e = emergencyGate({ detected: false, possible: false, type: 'NONE', confidence: 0 }, { yoloFall: { value: true, confidence: 0.75 } });
  assert.equal(e.possible, true);
  assert.equal(e.detected, false);
  const weak = emergencyGate({ detected: false, possible: false, type: 'NONE', confidence: 0 }, { yoloFall: { value: true, confidence: 0.6 } });
  assert.equal(weak.possible, false);
});

test('helmet absent at 0.9 plus gloves uncertain scores 31 (MEDIUM)', () => {
  const raw = [item('HELMET', 'ABSENT', 0.9, 'bare head'), item('GLOVES', 'UNCERTAIN', 0.4), item('REFLECTIVE_VEST', 'PRESENT', 0.9), item('SAFETY_BOOTS', 'PRESENT', 0.9)];
  const c = computeCriticality(normalizeItems(raw, REQ), {});
  assert.equal(c.score, 31);
  assert.equal(c.level, 'MEDIUM');
  assert.equal(c.drivers[0], 'Helmet absent (0.90)');
});

test('an emergency scores 100 (CRITICAL); bonuses apply', () => {
  const items = normalizeItems(allPresent(), REQ);
  const e = computeCriticality(items, { emergencyDetected: true });
  assert.equal(e.score, 100);
  assert.equal(e.level, 'CRITICAL');
  const b = computeCriticality(normalizeItems([item('HELMET', 'ABSENT', 0.9), item('REFLECTIVE_VEST', 'PRESENT', 0.9), item('SAFETY_BOOTS', 'PRESENT', 0.9), item('GLOVES', 'PRESENT', 0.9)], REQ), { repeatOffender: true, integrityFlags: ['STALE_PHOTO'], ageAtUploadMin: 22 });
  assert.equal(b.score, 27 + 10 + 15);
  assert.ok(b.drivers.includes('Photo taken 22 min before upload'));
});

test('level bands', () => {
  const cases = [[0, 'NONE'], [1, 'LOW'], [19, 'LOW'], [20, 'MEDIUM'], [44, 'MEDIUM'], [45, 'HIGH'], [69, 'HIGH'], [70, 'CRITICAL'], [100, 'CRITICAL']];
  for (const [s, l] of cases) assert.equal(levelFor(s), l, String(s));
});

test('hazard guard: emergency forces CRITICAL, IRRELEVANT forces LOW, scores follow the formula', () => {
  const base = { severity: 'MEDIUM', severity_confidence: 0.8, limitations: [], image_relevance: 'RELEVANT' };
  const g = hazardGuard(base, { detected: false });
  assert.equal(g.severity, 'MEDIUM');
  assert.equal(g.criticality.score, Math.round(55 * (0.7 + 0.3 * 0.8))); // 52
  assert.equal(hazardGuard(base, { detected: true }).severity, 'CRITICAL');
  const irr = hazardGuard({ ...base, image_relevance: 'IRRELEVANT', severity: 'CRITICAL' }, { detected: false });
  assert.equal(irr.severity, 'LOW');
  assert.ok(irr.limitations.length > 0);
});

test('composeSummary format and 300-char cap', () => {
  const s = composeSummary('NON_COMPLIANT', { level: 'HIGH', score: 58 }, 'Helmet absent.');
  assert.equal(s, 'Non-compliant · HIGH 58/100 — Helmet absent.');
  assert.ok(composeSummary('COMPLIANT', { level: 'NONE', score: 0 }, 'x'.repeat(500)).length <= 300);
});
