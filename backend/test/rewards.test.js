import test from 'node:test';
import assert from 'node:assert/strict';
import { HONOUR_TIERS, MONTH_RE, currentMonth, lastDayOf, pickHonours, previousMonth } from '../src/modules/rewards/rewards.service.js';

const row = (name, score, streak = 0, xp = 0) => ({ userId: name, name, score, streak, xp });

test('month helpers use IST and handle year rollover', () => {
  assert.equal(currentMonth(new Date('2026-03-31T19:00:00Z')), '2026-04'); // already 1 Apr in IST
  assert.equal(previousMonth(new Date('2026-01-10T00:00:00Z')), '2025-12');
  assert.equal(lastDayOf('2026-02'), '2026-02-28');
  assert.equal(lastDayOf('2028-02'), '2028-02-29');
  assert.ok(MONTH_RE.test('2026-12') && !MONTH_RE.test('2026-13') && !MONTH_RE.test('2026-1'));
});

test('top three earn honours with the configured demo values', () => {
  const h = pickHonours([row('A', 900), row('B', 800), row('C', 700), row('D', 600)]);
  assert.deepEqual(h.map((x) => [x.row.name, x.rank]), [['A', 1], ['B', 2], ['C', 3]]);
  assert.equal(h[0].stars, HONOUR_TIERS[0].stars);
  assert.equal(h[0].extraHolidays, 1);
});

test('workers with score 0 never earn an honour', () => {
  assert.deepEqual(pickHonours([row('A', 0), row('B', 0)]), []);
});

test('a tie for first gives both rank 1 and skips rank 2', () => {
  const h = pickHonours([row('A', 900, 5, 10), row('B', 900, 5, 10), row('C', 800)]);
  assert.deepEqual(h.map((x) => [x.row.name, x.rank]), [['A', 1], ['B', 1], ['C', 3]]);
});
