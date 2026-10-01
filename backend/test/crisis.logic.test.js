import test from 'node:test';
import assert from 'node:assert/strict';
import { accountedCounts, buildRoster, crisisTexts, mergeTrigger, newShareToken, setAccounted, validateResolve } from '../src/modules/crisis/crisis.logic.js';
import { trackPage } from '../src/modules/public-track/index.js';
import { buildCrisisReportPdf } from '../src/modules/crisis/crisis.report.js';

const base = () => ({ triggers: [{ type: 'SOS', refId: 's1' }], zoneIds: ['z1'], timeline: [] });
const code = (fn) => { try { fn(); return null; } catch (e) { return e.code; } };

test('share token is 24 URL-safe characters and unique', () => {
  const a = newShareToken();
  assert.match(a, /^[A-Za-z0-9_-]{24}$/);
  assert.notEqual(a, newShareToken());
});

test('a second trigger merges: zones are unioned, trigger added, timeline line added', () => {
  const { crisis, changed, line } = mergeTrigger(base(), { type: 'HAZARD_CRITICAL', refId: 'h1' }, ['z2'], 'Critical hazard: fire');
  assert.equal(changed, true);
  assert.deepEqual(crisis.zoneIds, ['z1', 'z2']);
  assert.equal(crisis.triggers.length, 2);
  assert.equal(crisis.timeline.length, 1);
  assert.match(line.text, /HAZARD_CRITICAL/);
});

test('the same trigger and zones again changes nothing', () => {
  const { changed } = mergeTrigger(base(), { type: 'SOS', refId: 's1' }, ['z1']);
  assert.equal(changed, false);
});

test('same trigger type with a new refId is a new trigger', () => {
  assert.equal(mergeTrigger(base(), { type: 'SOS', refId: 's2' }, ['z1']).crisis.triggers.length, 2);
});

test('resolve: a real crisis needs both checklist items', () => {
  assert.equal(code(() => validateResolve({ falseAlarm: false, note: 'all clear confirmed', checklist: { allAccounted: true, hazardsContained: false } })), 'CHECKLIST_INCOMPLETE');
  assert.equal(code(() => validateResolve({ falseAlarm: false, note: 'all clear confirmed' })), 'CHECKLIST_INCOMPLETE');
  assert.equal(code(() => validateResolve({ falseAlarm: false, note: 'all clear confirmed', checklist: { allAccounted: true, hazardsContained: true } })), null);
});

test('resolve: a false alarm needs no checklist but still needs a note of 10+ characters', () => {
  assert.equal(code(() => validateResolve({ falseAlarm: true, note: 'tested alarm' })), null);
  assert.equal(code(() => validateResolve({ falseAlarm: true, note: 'short' })), 'VALIDATION_ERROR');
});

test('roster defaults to UNKNOWN; SosCancelled style updates make a worker SAFE', () => {
  const miners = [{ _id: 'a', fullName: 'A', employeeId: 'M1', zoneId: 'z1' }, { _id: 'b', fullName: 'B', employeeId: 'M2', zoneId: 'z1' }];
  let acc = [];
  assert.equal(accountedCounts(buildRoster(miners, acc)).UNKNOWN, 2);
  acc = setAccounted(acc, 'a', 'SAFE');
  acc = setAccounted(acc, 'a', 'INJURED');
  assert.equal(acc.length, 1);
  const c = accountedCounts(buildRoster(miners, acc));
  assert.deepEqual([c.INJURED, c.UNKNOWN, c.total], [1, 1, 2]);
});

test('voice text <= 450 and SMS <= 320 characters, SMS carries the track link', () => {
  const { voice, sms } = crisisTexts({ reason: 'x'.repeat(900), zoneCodes: ['Z-A', 'Z-B'], trackUrl: 'https://x.test/public/track/abc' });
  assert.ok(voice.length <= 450);
  assert.ok(sms.length <= 320);
  const short = crisisTexts({ reason: 'Fire in Zone A', zoneCodes: ['Z-A'], trackUrl: 'https://x.test/public/track/abc' });
  assert.match(short.sms, /public\/track\/abc/);
});

test('public page is self-contained: auto-refresh, no external scripts, escaped text, counts only', () => {
  const html = trackPage({ startedAt: new Date('2026-03-10T10:00:00Z'), zones: ['Z-A'], counts: { total: 4, SAFE: 1, MISSING: 0, INJURED: 0, UNKNOWN: 3 }, reason: '<script>alert(1)</script>' });
  assert.match(html, /http-equiv="refresh" content="10"/);
  assert.doesNotMatch(html, /<script/);
  assert.match(html, /&lt;script&gt;/);
  assert.doesNotMatch(html, /https?:\/\//);
});

test('crisis report PDF renders', async () => {
  const buf = await buildCrisisReportPdf({
    crisisId: 'c1', startedAt: new Date(), resolvedAt: new Date(), durationMin: 12, triggers: [{ type: 'SOS' }], zones: [{ code: 'Z-A', name: 'Zone A' }], reason: 'x',
    resolution: { falseAlarm: false, note: 'all clear confirmed' }, accounted: { total: 1, SAFE: 1, MISSING: 0, INJURED: 0, UNKNOWN: 0 }, roster: [{ name: 'A', employeeId: 'M1', status: 'SAFE' }], timeline: [{ at: new Date(), text: 'Crisis activated' }], gpsPings: 3,
  });
  assert.equal(buf.subarray(0, 5).toString(), '%PDF-');
});
