import test from 'node:test';
import assert from 'node:assert/strict';
import { sosSmsText } from '../src/modules/sos/sos.service.js';

test('SOS SMS with location contains a maps link', () => {
  const t = sosSmsText({ name: 'Dinesh Oraon', zoneCode: 'Z-B', at: new Date('2026-01-01T09:00:00Z'), lat: 23.746012, lng: 86.4151 });
  assert.equal(t, 'SOS: Dinesh Oraon, Z-B, 14:30 IST, loc 23.74601,86.41510, maps https://maps.google.com/?q=23.74601,86.41510');
});

test('SOS SMS without location still sends', () => {
  const t = sosSmsText({ name: 'A B', zoneCode: 'Z-A', at: new Date('2026-01-01T09:00:00Z') });
  assert.equal(t, 'SOS: A B, Z-A, 14:30 IST, loc unknown');
});
