import test from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { computeIntegrityFlags, withinShiftWindow, istDateString } from '../src/modules/checkins/integrity.js';
import { analyzeQuality, sniffImageType } from '../src/modules/checkins/image-quality.js';

const d = (s) => new Date(s);
const base = (over = {}) => ({
  source: 'camera', exifTakenAt: null, capturedAt: d('2026-01-01T10:00:00Z'), queuedAt: null, uploadStartedAt: d('2026-01-01T10:01:00Z'),
  receivedAt: d('2026-01-01T10:01:02Z'), accuracyM: 10, hasLocation: true, insideZone: true, withinShift: true, ...over,
});

test('clean camera check-in has no flags', () => {
  assert.deepEqual(computeIntegrityFlags(base()).flags, []);
});

test('STALE_PHOTO when upload is >15 min after capture', () => {
  const { flags } = computeIntegrityFlags(base({ uploadStartedAt: d('2026-01-01T10:20:00Z'), receivedAt: d('2026-01-01T10:20:01Z') }));
  assert.ok(flags.includes('STALE_PHOTO'));
});

test('OFFLINE_DELAYED when queued >2 min before receipt', () => {
  const { flags } = computeIntegrityFlags(base({ queuedAt: d('2026-01-01T10:00:30Z'), uploadStartedAt: d('2026-01-01T10:05:00Z'), receivedAt: d('2026-01-01T10:05:01Z') }));
  assert.ok(flags.includes('OFFLINE_DELAYED'));
  assert.ok(!flags.includes('STALE_PHOTO'));
});

test('CLOCK_SKEW beyond 300 s, signed value stored', () => {
  const r = computeIntegrityFlags(base({ uploadStartedAt: d('2026-01-01T10:10:00Z'), receivedAt: d('2026-01-01T10:01:00Z') }));
  assert.ok(r.flags.includes('CLOCK_SKEW'));
  assert.equal(r.clockSkewSec, 540);
  const neg = computeIntegrityFlags(base({ uploadStartedAt: d('2026-01-01T09:50:00Z'), receivedAt: d('2026-01-01T10:01:00Z') }));
  assert.equal(neg.clockSkewSec, -660);
});

test('LOW_GPS_ACCURACY on weak or missing fix; OUTSIDE_ZONE; gallery flags', () => {
  assert.ok(computeIntegrityFlags(base({ accuracyM: 150 })).flags.includes('LOW_GPS_ACCURACY'));
  assert.ok(computeIntegrityFlags(base({ hasLocation: false })).flags.includes('LOW_GPS_ACCURACY'));
  assert.ok(computeIntegrityFlags(base({ insideZone: false })).flags.includes('OUTSIDE_ZONE'));
  const g = computeIntegrityFlags(base({ source: 'gallery' })).flags;
  assert.ok(g.includes('GALLERY_SOURCE') && g.includes('NO_EXIF'));
});

test('shift C across midnight: 22:30 and 05:30 IST inside, 14:00 outside', () => {
  // IST = UTC + 5:30. 22:30 IST = 17:00Z; 05:30 IST = 00:00Z; 14:00 IST = 08:30Z
  assert.equal(withinShiftWindow('C', d('2026-01-01T17:00:00Z')), true);
  assert.equal(withinShiftWindow('C', d('2026-01-01T00:00:00Z')), true);
  assert.equal(withinShiftWindow('C', d('2026-01-01T08:30:00Z')), false);
});

test('shift B window with 30 min tolerance', () => {
  assert.equal(withinShiftWindow('B', d('2026-01-01T09:00:00Z')), true); // 14:30 IST
  assert.equal(withinShiftWindow('B', d('2026-01-01T08:40:00Z')), true); // 14:10 IST
  assert.equal(withinShiftWindow('B', d('2026-01-01T03:00:00Z')), false); // 08:30 IST
});

test('IST date string crosses UTC midnight', () => {
  assert.equal(istDateString(d('2026-01-01T20:00:00Z')), '2026-01-02');
});

test('magic bytes', () => {
  assert.equal(sniffImageType(Buffer.from([0xff, 0xd8, 0xff, 0xe0])), 'jpeg');
  assert.equal(sniffImageType(Buffer.from([0x89, 0x50, 0x4e, 0x47])), 'png');
  assert.equal(sniffImageType(Buffer.from('GIF89a')), null);
});

async function checker(size, cell) {
  const raw = Buffer.alloc(size * size * 3);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const v = (Math.floor(x / cell) + Math.floor(y / cell)) % 2 === 0 ? 200 : 60;
    const i = (y * size + x) * 3;
    raw[i] = raw[i + 1] = raw[i + 2] = v;
  }
  return sharp(raw, { raw: { width: size, height: size, channels: 3 } }).jpeg({ quality: 92 }).toBuffer();
}

test('server quality: sharp passes, blurred rejected, dark rejected', async () => {
  const sharpBuf = await checker(800, 8);
  const ok = await analyzeQuality(sharpBuf);
  assert.equal(ok.pass, true);
  const blurred = await sharp(sharpBuf).blur(12).jpeg().toBuffer();
  const bad = await analyzeQuality(blurred);
  assert.ok(bad.reasons.includes('BLURRY'));
  const dark = await sharp({ create: { width: 800, height: 800, channels: 3, background: { r: 5, g: 5, b: 5 } } }).jpeg().toBuffer();
  const dk = await analyzeQuality(dark);
  assert.ok(dk.reasons.includes('TOO_DARK'));
  const small = await analyzeQuality(await checker(400, 8));
  assert.ok(small.reasons.includes('RESOLUTION_LOW'));
});
