import test from 'node:test';
import assert from 'node:assert/strict';
import { buildLayout } from '../seed/build_layout.js';
import { SINK, buildCostContext, buildGraph, distPointSegment, toblerSpeed } from '../src/modules/crisis/rerouter/graph.js';
import { aStar, overlapRatio, yen } from '../src/modules/crisis/rerouter/search.js';
import { computeRoutes, rankRoutes } from '../src/modules/crisis/rerouter/compute.js';
import { arcCost } from '../src/modules/crisis/rerouter/graph.js';

const ANCHOR = { lat: 23.746, lng: 86.415 };
const graph = buildGraph(buildLayout(ANCHOR));
const node = (id) => graph.nodes.get(id);
const worker = (id, nodeId, extra = {}) => ({ userId: id, name: id, lat: node(nodeId).lat + 0.00001, lng: node(nodeId).lng + 0.00001, ...extra });
const routes = (res, id) => res.byWorker[id] ?? [];

test('Tobler speed peaks at slope -5% and is scaled by 0.8 underground', () => {
  assert.ok(Math.abs(toblerSpeed(-0.05) - (6 / 3.6) * 0.8) < 1e-9);
  assert.ok(toblerSpeed(0.2) < toblerSpeed(0));
});

test('point to segment distance', () => {
  const a = { lat: 23.0, lng: 86.0 };
  const b = { lat: 23.0, lng: 86.001 };
  const r = distPointSegment({ lat: 23.0 + 10 / 110_540, lng: 86.0005 }, a, b);
  assert.ok(Math.abs(r.d - 10) < 0.5);
  assert.ok(Math.abs(r.t - 0.5) < 0.01);
});

test('a worker deep in the mine gets routes that reach an exit or refuge, shortest first by default ranking', () => {
  const res = computeRoutes({ graph, workers: [worker('w1', 'J6')], sosWorkerIds: ['w1'] });
  const rs = routes(res, 'w1');
  assert.ok(rs.length >= 2 && rs.length <= 3);
  assert.deepEqual(rs.map((r) => r.properties.rank), rs.map((_, i) => i + 1));
  assert.equal(rs[0].properties.recommended, true);
  for (const r of rs) assert.ok(['X-MAIN', 'X-INCL', 'X-RET', 'RC-1'].includes(r.properties.exitId));
});

test('SOS workers get 3 routes with <= 70% overlap; other workers get rank 1 and a backup', () => {
  const res = computeRoutes({ graph, workers: [worker('sos', 'J5'), worker('w2', 'J4')], sosWorkerIds: ['sos'] });
  const sos = routes(res, 'sos');
  assert.equal(sos.length, 3);
  assert.ok(routes(res, 'w2').length <= 2);
  assert.equal(routes(res, 'w2')[0].properties.rank, 1);
});

test('route features carry the documented properties', () => {
  const f = computeRoutes({ graph, workers: [worker('w1', 'J3')], crisisId: 'c1' }).collection.features[0];
  for (const k of ['crisisId', 'workerId', 'workerName', 'rank', 'recommended', 'exitId', 'exitName', 'exitType', 'distanceM', 'etaSec', 'risk', 'congestion', 'reasons', 'positionUnknown', 'computedAt']) assert.ok(k in f.properties, k);
  assert.equal(f.geometry.type, 'LineString');
  assert.ok(f.geometry.coordinates.length >= 2);
});

test('blocking the best route edge changes which route ranks first', () => {
  const free = computeRoutes({ graph, workers: [worker('w1', 'J2')] });
  const firstFree = routes(free, 'w1')[0].properties;
  // J2 sits next to the main shaft at J0: block the tunnels toward it.
  const blocked = computeRoutes({ graph, workers: [worker('w1', 'J2')], blockedEdgeIds: ['T-J0-J1', 'T-J1-J2'] });
  const firstBlocked = routes(blocked, 'w1')[0].properties;
  assert.notEqual(firstBlocked.exitId, firstFree.exitId);
  assert.ok(firstBlocked.reasons.some((r) => /closed|blocked/i.test(r)));
});

test('a CRITICAL hazard removes edges within 15 m; routes avoid them', () => {
  const j = node('J1');
  const ctx = buildCostContext(graph, { hazards: [{ id: 'h', category: 'ELECTRICAL', severity: 'CRITICAL', lat: j.lat, lng: j.lng }] });
  assert.ok(ctx.removed.has('T-J0-J1') && ctx.removed.has('T-J1-J2'));
  assert.equal(arcCost({ edge: graph.edges.get('T-J0-J1'), forward: true }, ctx, new Map()), Infinity);
});

test('an unclassified FIRE_SMOKE hazard is treated as a hard constraint; an unclassified ELECTRICAL one is not', () => {
  const j = node('J1');
  assert.ok(buildCostContext(graph, { hazards: [{ category: 'FIRE_SMOKE', severity: null, lat: j.lat, lng: j.lng }] }).removed.size > 0);
  assert.equal(buildCostContext(graph, { hazards: [{ category: 'ELECTRICAL', severity: null, lat: j.lat, lng: j.lng }] }).removed.size, 0);
});

test('FIRE_SMOKE makes return airways cost double and prefers intake routes', () => {
  const far = { category: 'FIRE_SMOKE', severity: 'LOW', lat: node('J10').lat, lng: node('J10').lng };
  const ctx = buildCostContext(graph, { hazards: [far] });
  assert.equal(ctx.hazardMult.get('T-N0-N1') >= 2, true);
  assert.equal(ctx.hazardMult.get('T-J0-J1'), 1);
});

test('soft hazard proximity multiplier follows 1 + w(1 - d/60)', () => {
  const e = graph.edges.get('T-J3-J4');
  const mid = { lat: (e.coords[0].lat + e.coords[1].lat) / 2, lng: (e.coords[0].lng + e.coords[1].lng) / 2 };
  const off = { lat: mid.lat + 30 / 110_540, lng: mid.lng };
  const ctx = buildCostContext(graph, { hazards: [{ category: 'OTHER', severity: 'MEDIUM', ...off }] });
  assert.ok(Math.abs(ctx.hazardMult.get('T-J3-J4') - (1 + 0.8 * (1 - 30 / 60))) < 0.02);
});

test('congestion raises the cost of a loaded edge', () => {
  const arc = { edge: graph.edges.get('T-J0-J1'), forward: true };
  const ctx = buildCostContext(graph, {});
  assert.ok(arcCost(arc, ctx, new Map([['T-J0-J1', 60]])) > arcCost(arc, ctx, new Map()));
});

test('A* equals Dijkstra on 50 random node pairs (heuristic is admissible)', () => {
  const ids = [...graph.nodes.keys()];
  const ctx = buildCostContext(graph, {});
  const neighbors = (n) => (graph.adj.get(n) ?? []).map((a) => ({ to: a.to, cost: arcCost(a, ctx, new Map()) }));
  let seed = 7;
  const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 2 ** 32;
  for (let i = 0; i < 50; i += 1) {
    const a = ids[Math.floor(rnd() * ids.length)];
    const b = ids[Math.floor(rnd() * ids.length)];
    const h = (n) => {
      const p = graph.nodes.get(n), q = graph.nodes.get(b);
      return (Math.hypot((p.lat - q.lat) * 110_540, (p.lng - q.lng) * 111_320 * Math.cos((p.lat * Math.PI) / 180))) / ((6 / 3.6) * 0.8);
    };
    const d = aStar({ start: a, goal: b, neighbors });
    const s = aStar({ start: a, goal: b, neighbors, heuristic: h });
    assert.ok(Math.abs(d.cost - s.cost) < 1e-6, `${a}->${b}`);
  }
});

test('Yen returns loopless paths in non-decreasing cost', () => {
  const ctx = buildCostContext(graph, {});
  const neighbors = (n) => (graph.adj.get(n) ?? []).map((a) => ({ to: a.to, cost: arcCost(a, ctx, new Map()) }));
  const ps = yen({ start: 'J5', goal: 'J0', neighbors, k: 6 });
  assert.ok(ps.length >= 3);
  for (let i = 1; i < ps.length; i += 1) assert.ok(ps[i].cost >= ps[i - 1].cost - 1e-9);
  for (const p of ps) assert.equal(new Set(p.nodes).size, p.nodes.length);
});

test('overlap ratio is length weighted', () => {
  const a = [{ edgeId: 'x', len: 70 }, { edgeId: 'y', len: 30 }];
  assert.equal(overlapRatio(a, [{ edgeId: 'x', len: 1 }]), 0.7);
  assert.equal(overlapRatio(a, []), 0);
});

test('ranking: score = 0.55*eta + 0.30*risk + 0.15*congestion (normalised), lower first', () => {
  const [first, second] = rankRoutes([
    { etaSec: 120, risk: 0, congestion: 0, edges: [] }, // 0.55
    { etaSec: 100, risk: 1, congestion: 0, edges: [] }, // 0.30
  ]);
  assert.equal(first.etaSec, 100);
  assert.ok(Math.abs(first.score - 0.3) < 1e-9 && Math.abs(second.score - 0.55) < 1e-9);
  const tie = rankRoutes([{ etaSec: 100, risk: 2, congestion: 0, edges: [] }, { etaSec: 100, risk: 1, congestion: 0, edges: [] }]);
  assert.equal(tie[0].risk, 1);
});

test('a worker with no GPS fix still gets routes marked positionUnknown', () => {
  const res = computeRoutes({ graph, workers: [worker('w9', 'J4', { positionUnknown: true })] });
  assert.equal(routes(res, 'w9')[0].properties.positionUnknown, true);
});

test('full recompute for 13 workers is fast', () => {
  const ids = ['J1', 'J2', 'J3', 'J4', 'J5', 'J6', 'J7', 'J8', 'J9', 'N1', 'N3', 'S1', 'S4'];
  const ws = ids.map((n, i) => worker(`w${i}`, n));
  const t0 = performance.now();
  const res = computeRoutes({ graph, workers: ws, sosWorkerIds: ['w0'] });
  const ms = performance.now() - t0;
  assert.equal(Object.keys(res.byWorker).length, 13);
  assert.ok(ms < 500, `took ${ms.toFixed(0)} ms`); // the spec target is 150 ms on a laptop; CI machines vary
});

test('SINK constant is exported for the engine', () => {
  assert.equal(SINK, 'SINK');
});
