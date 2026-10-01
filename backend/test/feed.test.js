import test from 'node:test';
import assert from 'node:assert/strict';
import { istDayStart } from '../src/modules/feed/feed.service.js';

test('IST day starts at 18:30Z of the previous UTC day', () => {
  // 2026-01-01T20:00Z = 2026-01-02 01:30 IST -> day start 2026-01-02 00:00 IST = 2026-01-01T18:30Z
  assert.equal(istDayStart(new Date('2026-01-01T20:00:00Z')).toISOString(), '2026-01-01T18:30:00.000Z');
  // 2026-01-01T10:00Z = 15:30 IST same day -> start 2025-12-31T18:30Z
  assert.equal(istDayStart(new Date('2026-01-01T10:00:00Z')).toISOString(), '2025-12-31T18:30:00.000Z');
});
