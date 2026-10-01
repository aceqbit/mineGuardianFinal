import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLayout, layoutStats } from '../seed/build_layout.js';

test('layout meets structural requirements', () => {
  const g = buildLayout({ lat: 23.746, lng: 86.415 });
  const s = layoutStats(g);
  assert.ok(s.tunnels >= 30);
  assert.equal(s.exits, 3);
  assert.equal(s.refuges, 1);
  assert.equal(s.zones, 3);
  const t = g.features.find((f) => f.properties.kind === 'tunnel' && f.properties.id === 'T-J0-J1');
  assert.equal(t.properties.slopePct, 1.5);
  assert.equal(t.geometry.type, 'LineString');
});
