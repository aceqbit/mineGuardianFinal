import test from 'node:test';
import assert from 'node:assert/strict';
import { computeScore, rankRows, recency, windowDays } from '../src/modules/scoring/score.formula.js';
import { buildDayMap, minutesAfterShiftStart } from '../src/modules/scoring/scoring.service.js';

// 2026-03-14 is a Saturday; 2026-03-15 a Sunday.
const TODAY = '2026-03-14';
const ok = (over = {}) => ({ verdict: 'COMPLIANT', firstPass: true, minutesAfterStart: 5, missing: [], frozen: false, critical: false, ...over });
const allDays = (mk) => Object.fromEntries(windowDays(TODAY).filter((d) => new Date(`${d}T00:00:00Z`).getUTCDay() !== 0).map((d) => [d, mk(d)]));

test('perfect worker: score is capped at 1000 with a long streak and GREEN band', () => {
  const r = computeScore({ today: TODAY, days: allDays(() => ok()) });
  assert.equal(r.score, 1000);
  assert.ok(r.streak >= 25);
  assert.equal(r.riskBand, 'GREEN');
});

test('no data: score 0 and the minimal risk rule (score < 400) makes the band RED', () => {
  const r = computeScore({ today: TODAY, days: {} });
  assert.equal(r.score, 0);
  assert.equal(r.riskBand, 'RED');
});

test('a missing HELMET costs more than another missing item', () => {
  const base = (missing) => computeScore({ today: TODAY, days: { ...allDays(() => ok()), [TODAY]: ok({ verdict: 'NON_COMPLIANT', missing, critical: false }) } });
  assert.ok(base(['HELMET']).components.V > base(['GLOVES']).components.V);
  assert.equal(+(base(['HELMET']).components.V / base(['GLOVES']).components.V).toFixed(2), 1.5);
});

test('a frozen day is excluded from C and does not break the streak', () => {
  const days = allDays(() => ok());
  const frozenDay = windowDays(TODAY)[27];
  days[frozenDay] = ok({ verdict: 'NON_COMPLIANT', frozen: true });
  const r = computeScore({ today: TODAY, days });
  assert.ok(r.streak > 5);
  assert.equal(r.components.C, 1);
});

test('today without a check-in does not hurt the score', () => {
  const days = allDays(() => ok());
  delete days[TODAY];
  assert.equal(computeScore({ today: TODAY, days }).components.C, 1);
});

test('hazard bonus H clamps at 150 and rejections subtract', () => {
  const many = Array.from({ length: 20 }, () => ({ day: TODAY, kind: 'CLOSED', severity: 'CRITICAL' }));
  assert.equal(computeScore({ today: TODAY, days: {}, hazards: many }).components.H, 150);
  assert.equal(computeScore({ today: TODAY, days: {}, hazards: [{ day: TODAY, kind: 'REJECTED', severity: null }] }).components.H, -15);
  assert.equal(computeScore({ today: TODAY, days: {}, hazards: [{ day: TODAY, kind: 'CLOSED', severity: null }] }).components.H, 10);
});

test('risk band: any NON_COMPLIANT in 7 days is at least AMBER; three in 30 days is RED', () => {
  const amber = computeScore({ today: TODAY, days: { ...allDays(() => ok()), [TODAY]: ok({ verdict: 'NON_COMPLIANT', missing: ['GLOVES'] }) } });
  assert.equal(amber.riskBand, 'AMBER');
  const ds = allDays(() => ok());
  const wd = Object.keys(ds);
  for (const d of wd.slice(0, 3)) ds[d] = ok({ verdict: 'NON_COMPLIANT', missing: ['GLOVES'] });
  assert.equal(computeScore({ today: TODAY, days: ds }).riskBand, 'RED');
});

test('a CRITICAL violation in the last 7 days forces RED', () => {
  const r = computeScore({ today: TODAY, days: { ...allDays(() => ok()), [TODAY]: ok({ verdict: 'NON_COMPLIANT', missing: ['HELMET'], critical: true }) } });
  assert.equal(r.riskBand, 'RED');
});

test('badges keep their original earnedAt and feed B (max 50)', () => {
  const earned = new Date('2026-03-01T00:00:00Z');
  const r = computeScore({ today: TODAY, days: allDays(() => ok()), priorBadges: [{ key: 'STREAK_7', earnedAt: earned }], now: new Date('2026-03-14T10:00:00Z') });
  assert.equal(r.badges.find((b) => b.key === 'STREAK_7').earnedAt.toISOString(), earned.toISOString());
  assert.ok(r.components.B <= 50 && r.components.B >= 10);
});

test('recency decays by e^(-age/15)', () => {
  assert.ok(Math.abs(recency(15) - Math.exp(-1)) < 1e-9);
  assert.equal(recency(0), 1);
});

test('standard competition ranking: ties share a rank and the next rank skips', () => {
  const rows = rankRows([
    { name: 'B', score: 900, streak: 3, xp: 10 },
    { name: 'A', score: 900, streak: 3, xp: 10 },
    { name: 'C', score: 800, streak: 1, xp: 0 },
    { name: 'D', score: 900, streak: 5, xp: 0 },
  ]);
  assert.deepEqual(rows.map((r) => [r.name, r.rank]), [['D', 1], ['A', 2], ['B', 2], ['C', 4]]);
});

test('minutesAfterShiftStart handles shifts A and C (night)', () => {
  // Shift A starts 06:00 IST = 00:30Z. 06:12 IST -> 12 min.
  assert.equal(minutesAfterShiftStart('A', new Date('2026-03-14T00:42:00Z')), 12);
  // Shift C starts 22:00 IST. 22:10 IST -> 10; 00:10 IST next day -> 130.
  assert.equal(minutesAfterShiftStart('C', new Date('2026-03-14T16:40:00Z')), 10);
  assert.equal(minutesAfterShiftStart('C', new Date('2026-03-14T18:40:00Z')), 130);
});

test('buildDayMap keeps the latest decision per IST day and flags critical PPE', () => {
  const mk = (decidedAt, verdict, items, attempt = 1) => ({
    review: { decision: { decidedAt, finalVerdict: verdict, items }, sla: {}, ai: {} },
    checkIn: { capturedAt: new Date('2026-03-14T03:00:00Z'), attempt },
    shift: 'A',
  });
  const map = buildDayMap([
    mk('2026-03-14T04:00:00Z', 'NON_COMPLIANT', [{ key: 'HELMET', status: 'ABSENT' }]),
    mk('2026-03-14T05:00:00Z', 'COMPLIANT', [{ key: 'HELMET', status: 'PRESENT' }], 2),
  ]);
  assert.equal(map['2026-03-14'].verdict, 'COMPLIANT');
  assert.equal(map['2026-03-14'].firstPass, false);
  const crit = buildDayMap([mk('2026-03-14T04:00:00Z', 'NON_COMPLIANT', [{ key: 'HELMET', status: 'ABSENT' }])]);
  assert.equal(crit['2026-03-14'].critical, true);
});
