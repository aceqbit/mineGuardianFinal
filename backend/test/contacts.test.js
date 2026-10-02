import test from 'node:test';
import assert from 'node:assert/strict';
import { EMERGENCY_BLOCKLIST, SMS_MAX, VOICE_MAX, assertSafeDialTarget, buildContactMessage } from '../src/modules/contacts/contacts.logic.js';

const code = (n) => { try { assertSafeDialTarget(n); return null; } catch (e) { return e.code; } };

test('the blocklist holds every number the spec names', () => {
  for (const n of ['112', '100', '101', '102', '108', '1070', '1077', '1078', '911', '999']) assert.ok(EMERGENCY_BLOCKLIST.includes(n), n);
});

test('real emergency numbers and short codes are refused as dial targets', () => {
  for (const bad of ['+91112', '+91100', '+91101', '+91102', '+91108', '+911070', '+911077', '+911078', '+1911', '+44999', '+91999']) {
    assert.equal(code(bad), 'UNSAFE_DIAL_TARGET', bad);
  }
});

test('malformed numbers are refused', () => {
  for (const bad of ['', '9876500001', '+', '+0123456789', '+91 98765 00001', 'abc', null, undefined, 123]) assert.equal(code(bad), 'UNSAFE_DIAL_TARGET', String(bad));
});

test('a normal verified team number is accepted', () => {
  assert.equal(code('+919876500001'), null);
  assert.equal(code('+14155552671'), null);
});

test('a number that merely contains an emergency number is fine', () => {
  assert.equal(code('+919876510112'), null);
});

test('voice <= 450 and sms <= 320 characters; the track link rides on the SMS', () => {
  const m = buildContactMessage({ crisis: { reason: 'x'.repeat(900), zoneCodes: ['Z-A'] }, trackUrl: 'https://x.test/public/track/abc' });
  assert.ok(m.voice.length <= VOICE_MAX && m.sms.length <= SMS_MAX);
  const short = buildContactMessage({ crisis: { reason: 'Fire', zoneCodes: ['Z-A'] }, trackUrl: 'https://x.test/public/track/abc' });
  assert.match(short.sms, /public\/track\/abc/);
  assert.match(buildContactMessage({}).voice, /test message/i);
  assert.match(buildContactMessage({ custom: 'Custom words' }).sms, /^Custom words/);
});
