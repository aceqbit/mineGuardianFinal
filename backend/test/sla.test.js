import test from 'node:test';
import assert from 'node:assert/strict';
import { breachOffsetMin, reliability, reminderOffsetMin, slaAction } from '../src/modules/admin-normal/sla.js';
import { buildDailyReportPdf } from '../src/modules/admin-normal/report.pdf.js';

const BASE = 5;
const DUE = new Date('2026-03-10T10:00:00Z');
const at = (min) => new Date(DUE.getTime() + min * 60_000);
const review = (sla = {}, status = 'PENDING_REVIEW') => ({ status, sla: { dueAt: DUE, remindersSent: 0, breached: false, ...sla } });

test('schedule with base 5: reminders at +0/+5/+15, breach at +35', () => {
  assert.deepEqual([0, 1, 2].map((n) => reminderOffsetMin(n, BASE)), [0, 5, 15]);
  assert.equal(breachOffsetMin(BASE), 35);
});

test('nothing happens before dueAt', () => {
  assert.equal(slaAction(review(), at(-1), BASE), null);
});

test('reminder 0 at dueAt, reminder 1 at +5, reminder 2 at +15, breach at +35', () => {
  assert.deepEqual(slaAction(review(), at(0), BASE), { type: 'REMIND', n: 0 });
  assert.equal(slaAction(review({ remindersSent: 1 }), at(4), BASE), null);
  assert.deepEqual(slaAction(review({ remindersSent: 1 }), at(5), BASE), { type: 'REMIND', n: 1 });
  assert.deepEqual(slaAction(review({ remindersSent: 2 }), at(15), BASE), { type: 'REMIND', n: 2 });
  assert.equal(slaAction(review({ remindersSent: 3 }), at(34), BASE), null);
  assert.deepEqual(slaAction(review({ remindersSent: 3 }), at(35), BASE), { type: 'BREACH' });
});

test('after a restart the persisted remindersSent prevents any resend', () => {
  // The service had already sent all three reminders; a fresh process at +20 min must do nothing.
  assert.equal(slaAction(review({ remindersSent: 3 }), at(20), BASE), null);
  // A review whose reminder 0 was sent does not send reminder 0 again at +1.
  assert.equal(slaAction(review({ remindersSent: 1 }), at(1), BASE), null);
});

test('downtime past the breach time goes straight to BREACH', () => {
  assert.deepEqual(slaAction(review({ remindersSent: 0 }), at(500), BASE), { type: 'BREACH' });
});

test('decided or already breached reviews are ignored', () => {
  assert.equal(slaAction(review({}, 'DECIDED'), at(50), BASE), null);
  assert.equal(slaAction(review({ breached: true }), at(50), BASE), null);
});

test('reliability = clamp(round(100*onTime/total - 5*breaches), 0, 100); no data = 100', () => {
  assert.equal(reliability({ onTime: 0, total: 0, breaches: 0 }), 100);
  assert.equal(reliability({ onTime: 9, total: 10, breaches: 0 }), 90);
  assert.equal(reliability({ onTime: 9, total: 10, breaches: 2 }), 80);
  assert.equal(reliability({ onTime: 1, total: 10, breaches: 5 }), 0);
});

test('daily report PDF renders to a valid PDF buffer', async () => {
  const buf = await buildDailyReportPdf({
    day: '2026-03-10', checkIns: 12, reviewed: 10, compliant: 8, nonCompliant: 2, compliancePct: 80, overrides: 1, escalations: 0, slaBreaches: 0,
    zones: [{ code: 'Z-A', name: 'Zone A', reviewed: 4, compliant: 3, compliancePct: 75 }], missingPpe: [{ key: 'GLOVES', count: 2 }], hazards: { opened: 3, closed: 1, critical: 0 }, sosEvents: 0,
  });
  assert.equal(buf.subarray(0, 5).toString(), '%PDF-');
});
