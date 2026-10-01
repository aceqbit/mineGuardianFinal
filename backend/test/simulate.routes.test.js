import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLayout } from '../seed/build_layout.js';
import { buildGraph, routesFrom } from '../dev/simulate-phase2.js';

test('simulator builds 3 routes to 3 different exits, shortest first', () => {
  const layout = { geojson: buildLayout({ lat: 23.746, lng: 86.415 }) };
  const g = buildGraph(layout);
  const routes = routesFrom(g, 'J5', 3);
  assert.equal(routes.length, 3);
  assert.equal(new Set(routes.map((r) => r.exit.id)).size, 3);
  for (let i = 1; i < routes.length; i++) assert.ok(routes[i].distanceM >= routes[i - 1].distanceM);
  for (const r of routes) assert.ok(r.coords.length >= 2);
});
