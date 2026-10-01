import test from 'node:test';
import assert from 'node:assert/strict';
import { checkTransition, hazardSmsText } from '../src/modules/hazards/hazards.service.js';

const ok = (from, to, note) => assert.equal(checkTransition(from, to, note), null, `${from}->${to}`);
const code = (from, to, note) => checkTransition(from, to, note)?.code;

test('allowed transitions', () => {
  ok('OPEN', 'ACKNOWLEDGED');
  ok('OPEN', 'CLOSED', 'fixed the cable');
  ok('ACKNOWLEDGED', 'CLOSED', 'made safe by electrician');
  ok('OPEN', 'REJECTED', 'duplicate report');
  ok('ACKNOWLEDGED', 'REJECTED', 'not a hazard');
});

test('closing needs a note of at least 5 characters; rejecting needs a note', () => {
  assert.equal(code('OPEN', 'CLOSED'), 'VALIDATION_ERROR');
  assert.equal(code('OPEN', 'CLOSED', 'ok'), 'VALIDATION_ERROR');
  assert.equal(code('OPEN', 'REJECTED'), 'VALIDATION_ERROR');
  assert.equal(code('OPEN', 'REJECTED', '   '), 'VALIDATION_ERROR');
});

test('everything else is INVALID_TRANSITION (409)', () => {
  assert.equal(code('ACKNOWLEDGED', 'ACKNOWLEDGED'), 'INVALID_TRANSITION');
  assert.equal(code('CLOSED', 'ACKNOWLEDGED'), 'INVALID_TRANSITION');
  assert.equal(code('CLOSED', 'CLOSED', 'again please'), 'INVALID_TRANSITION');
  assert.equal(code('REJECTED', 'CLOSED', 'reopen it'), 'INVALID_TRANSITION');
  assert.equal(checkTransition('CLOSED', 'REJECTED', 'nope nope').status, 409);
});

test('OPEN is not a valid target status', () => {
  assert.equal(code('ACKNOWLEDGED', 'OPEN'), 'VALIDATION_ERROR');
});

test('supervisor SMS text', () => {
  const t = hazardSmsText({ category: 'ELECTRICAL', zoneCode: 'Z-B', reporterName: 'Dinesh Oraon', at: new Date('2026-01-01T09:00:00Z'), lat: 23.74601234, lng: 86.4150999 });
  assert.equal(t, 'MINE GUARDIAN HAZARD: Electrical danger in Z-B by Dinesh Oraon at 14:30 IST. Loc 23.74601,86.41510. Open the app to act.');
});
