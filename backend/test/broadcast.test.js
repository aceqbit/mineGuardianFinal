import test from 'node:test';
import assert from 'node:assert/strict';
import { MAX_SMS_TARGETS, applyAck, authorizeSend, reaches, roomsFor, smsTargets, smsText } from '../src/modules/broadcast/broadcast.logic.js';

const code = (fn) => { try { fn(); return null; } catch (e) { return e.code; } };
const admin = { role: 'admin' };
const sup = { role: 'supervisor', zoneId: 'z1' };

test('admin may send any scope', () => {
  assert.equal(code(() => authorizeSend(admin, { scope: 'ALL' })), null);
  assert.equal(code(() => authorizeSend(admin, { scope: 'ROLE', role: 'miner' })), null);
  assert.equal(code(() => authorizeSend(admin, { scope: 'ZONE', zoneId: 'z9' })), null);
});

test('a supervisor may only send ZONE of their own zone (otherwise 403)', () => {
  assert.equal(code(() => authorizeSend(sup, { scope: 'ZONE', zoneId: 'z1' })), null);
  assert.equal(code(() => authorizeSend(sup, { scope: 'ZONE', zoneId: 'z2' })), 'FORBIDDEN_ROLE');
  assert.equal(code(() => authorizeSend(sup, { scope: 'ALL' })), 'FORBIDDEN_ROLE');
  assert.equal(code(() => authorizeSend(sup, { scope: 'ROLE', role: 'miner' })), 'FORBIDDEN_ROLE');
});

test('rooms by scope', () => {
  assert.deepEqual(roomsFor({ scope: 'ALL' }), ['*']);
  assert.deepEqual(roomsFor({ scope: 'ZONE', zoneId: 'z1' }), ['zone:z1']);
  assert.deepEqual(roomsFor({ scope: 'ROLE', role: 'miner' }), ['role:miner']);
});

test('catch-up targeting matches the scope', () => {
  const miner = { role: 'miner', zoneId: 'z1' };
  assert.equal(reaches({ scope: 'ALL' }, miner), true);
  assert.equal(reaches({ scope: 'ZONE', zoneId: 'z1' }, miner), true);
  assert.equal(reaches({ scope: 'ZONE', zoneId: 'z2' }, miner), false);
  assert.equal(reaches({ scope: 'ROLE', role: 'supervisor' }, miner), false);
});

test('EMERGENCY SMS goes only to offline people, capped at 20', () => {
  const users = Array.from({ length: 50 }, (_, i) => ({ _id: `u${i}`, phone: { e164: `+9198765000${String(i).padStart(2, '0')}` } }));
  const online = new Set(['u0', 'u1']);
  const t = smsTargets(users, (id) => online.has(id));
  assert.equal(t.length, MAX_SMS_TARGETS);
  assert.ok(!t.some((u) => online.has(u._id)));
  assert.equal(smsTargets([{ _id: 'x' }], () => false).length, 0); // no phone, no SMS
});

test('SMS text is prefixed and at most 320 characters', () => {
  const s = smsText({ priority: 'EMERGENCY', text: 'x'.repeat(280) });
  assert.match(s, /^MINE GUARDIAN EMERGENCY: /);
  assert.ok(s.length <= 320);
});

test('acks: READ implies DELIVERED, duplicates change nothing', () => {
  let s = { delivered: new Set(), read: new Set() };
  let r = applyAck(s, 'u1', 'DELIVERED');
  assert.equal(r.changed, true);
  s = r;
  assert.equal(applyAck(s, 'u1', 'DELIVERED').changed, false);
  r = applyAck(s, 'u1', 'READ');
  assert.equal(r.changed, true);
  assert.equal(r.read.size, 1);
  assert.equal(applyAck({ delivered: new Set(), read: new Set() }, 'u2', 'READ').delivered.has('u2'), true);
});
