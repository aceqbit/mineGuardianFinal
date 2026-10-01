import test from 'node:test';
import assert from 'node:assert/strict';
import { publish, subscribe } from '../src/core/bus.js';
import { haversineM, pointInPolygon, metersToLatLng } from '../src/core/geo.js';
import { maskPhone } from '../src/core/logger.js';
import { parseEnv } from '../src/config/env.js';

const tick = () => new Promise((r) => setTimeout(r, 20));

test('bus delivers envelope and isolates a throwing handler', async () => {
  const got = [];
  subscribe('CheckInCreated', () => {
    throw new Error('boom');
  });
  subscribe('CheckInCreated', (env) => got.push(env));
  publish('CheckInCreated', { checkInId: 'x' });
  await tick();
  assert.equal(got.length, 1);
  assert.equal(got[0].v, 1);
  assert.equal(got[0].data.checkInId, 'x');
  assert.ok(got[0].id && got[0].ts);
});

test('bus rejects unknown event', () => {
  assert.throws(() => publish('Nope', {}), /Unknown bus event/);
});

test('one degree of latitude is ~111 km', () => {
  const d = haversineM({ lat: 10, lng: 20 }, { lat: 11, lng: 20 });
  assert.ok(Math.abs(d - 111195) / 111195 < 0.005);
});

test('point in polygon', () => {
  const poly = { type: 'Polygon', coordinates: [[[0, 0], [10, 0], [10, 10], [0, 10], [0, 0]]] };
  assert.equal(pointInPolygon({ lat: 5, lng: 5 }, poly), true);
  assert.equal(pointInPolygon({ lat: 15, lng: 5 }, poly), false);
});

test('metersToLatLng', () => {
  const { dLat } = metersToLatLng(0, 111320, 0);
  assert.ok(Math.abs(dLat - 1) < 1e-9);
});

test('maskPhone', () => {
  assert.equal(maskPhone('+919876500101'), '+91******0101');
});

test('env: missing required vars are reported; fast mode divides SLA', () => {
  assert.throws(() => parseEnv({}, { exit: false }), /MONGODB_URI/);
  const e = parseEnv(
    { MONGODB_URI: 'm', FIREBASE_PROJECT_ID: 'p', FIREBASE_STORAGE_BUCKET: 'b', DEMO_FAST_MODE: 'true', SLA_MINUTES: '30', SLA_REMINDER_BASE_MINUTES: '5' },
    { exit: false },
  );
  assert.equal(e.slaMinutes, 2);
  assert.ok(Math.abs(e.slaReminderBaseMinutes - 1 / 3) < 1e-9);
  assert.equal(e.TWILIO_DRY_RUN, true);
});
