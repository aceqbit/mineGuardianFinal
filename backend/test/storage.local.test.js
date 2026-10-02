import test from 'node:test';
import assert from 'node:assert/strict';
import { parseEnv } from '../src/config/env.js';
import { safeJoin, signToken, verifyToken } from '../src/core/storage.js';

test('tokens verify, expire and reject tampering', () => {
  const t = signToken('checkins/a/b.jpg', Date.now() + 60_000, 'k');
  assert.equal(verifyToken(t, 'k'), 'checkins/a/b.jpg');
  assert.equal(verifyToken(t, 'other-key'), null);
  assert.equal(verifyToken(t.replace(/.$/, (c) => (c === 'A' ? 'B' : 'A')), 'k'), null);
  assert.equal(verifyToken(signToken('x.jpg', Date.now() - 1, 'k'), 'k'), null);
  assert.equal(verifyToken('garbage', 'k'), null);
});

test('storage paths cannot escape the root folder', () => {
  assert.ok(safeJoin('/data', 'checkins/a.jpg').endsWith('a.jpg'));
  assert.throws(() => safeJoin('/data', '../secrets/firebase-sa.json'));
  assert.throws(() => safeJoin('/data', '/etc/passwd'));
});

test('firebase driver still requires a bucket; local driver does not', () => {
  const base = { MONGODB_URI: 'x', FIREBASE_PROJECT_ID: 'p' };
  assert.throws(() => parseEnv(base, { exit: false }), /FIREBASE_STORAGE_BUCKET/);
  assert.equal(parseEnv({ ...base, STORAGE_DRIVER: 'local' }, { exit: false }).STORAGE_DRIVER, 'local');
  assert.equal(parseEnv({ ...base, FIREBASE_STORAGE_BUCKET: 'b' }, { exit: false }).STORAGE_DRIVER, 'firebase');
});
