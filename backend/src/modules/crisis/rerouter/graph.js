// Mine graph + edge costs (CLAUDE.md §13, Rerouter). Pure: no I/O.
import { haversineM } from '../../../core/geo.js';

export const SINK = 'SINK';
export const UNDERGROUND = 0.8;
export const VMAX = (6 / 3.6) * UNDERGROUND; // m/s, upper bound of Tobler speed -> admissible heuristic
export const REFUGE_PENALTY_S = 120;
export const HARD_RADIUS_M = 15;
export const SOFT_RADIUS_M = 60;
export const FIRE_RADIUS_M = 100;
const SEVERITY_W = { LOW: 0.3, MEDIUM: 0.8, CRITICAL: 2.0 };
const HARD_UNCLASSIFIED = new Set(['FIRE_SMOKE', 'FLOODING', 'ROOF_FALL', 'GAS_LEAK']);

const ll = (c) => ({ lng: c[0], lat: c[1] });

/** Distance from point p to segment a-b in metres, plus the clamped position t (0..1) and the projected point. */
export function distPointSegment(p, a, b) {
  const lat0 = (a.lat + b.lat) / 2;
  const kx = Math.cos((lat0 * Math.PI) / 180) * 111_320;
  const ky = 110_540;
  const ax = a.lng * kx, ay = a.lat * ky, bx = b.lng * kx, by = b.lat * ky, px = p.lng * kx, py = p.lat * ky;
  const dx = bx - ax, dy = by - ay;
  const len2 = dx * dx + dy * dy;
  const t = len2 === 0 ? 0 : Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / len2));
  const qx = ax + t * dx, qy = ay + t * dy;
  return { d: Math.hypot(px - qx, py - qy), t, proj: { lat: qy / ky, lng: qx / kx } };
}

/** Tobler hiking function on slope s (rise/run): km/h, scaled for underground. Returns m/s. */
export function toblerSpeed(slopeFraction) {
  return ((6 * Math.exp(-3.5 * Math.abs(slopeFraction + 0.05))) / 3.6) * UNDERGROUND;
}

/**
 * Directed graph from a layout FeatureCollection.
 * node ids are junction ids; arcs carry edge id, direction, length, base time and geometry.
 */
export function buildGraph(geojson) {
  const feats = geojson.features;
  const nodes = new Map();
  for (const f of feats) if (f.properties.kind === 'junction') nodes.set(f.properties.id, ll(f.geometry.coordinates));
  const edges = new Map();
  const adj = new Map([...nodes.keys()].map((k) => [k, []]));
  for (const f of feats.filter((x) => x.properties.kind === 'tunnel')) {
    const p = f.properties;
    const coords = f.geometry.coordinates.map(ll);
    let length = 0;
    for (let i = 1; i < coords.length; i += 1) length += haversineM(coords[i - 1], coords[i]);
    const edge = { id: p.id, from: p.fromNode, to: p.toNode, length, widthM: p.widthM, capacity: p.capacity, slopePct: p.slopePct ?? 0, airway: p.airway, blocked: p.status === 'blocked', coords };
    edges.set(p.id, edge);
    adj.get(p.fromNode).push({ edge, to: p.toNode, forward: true });
    adj.get(p.toNode).push({ edge, to: p.fromNode, forward: false });
  }
  const exits = feats.filter((f) => f.properties.kind === 'exit').map((f) => ({ id: f.properties.id, name: f.properties.name, exitType: f.properties.exitType, node: f.properties.node, kind: 'exit' }));
  const refuges = feats.filter((f) => f.properties.kind === 'refuge').map((f) => ({ id: f.properties.id, name: f.properties.name, exitType: 'refuge', node: f.properties.node, kind: 'refuge' }));
  const zones = feats.filter((f) => f.properties.kind === 'zone').map((f) => ({ code: f.properties.code, geometry: f.geometry }));
  return { nodes, edges, adj, exits, refuges, targets: [...exits, ...refuges], zones };
}

/** Slope along the direction of travel, as a fraction. */
export const arcSlope = (arc) => (arc.forward ? arc.edge.slopePct : -arc.edge.slopePct) / 100;

/** Base travel time in seconds. */
export const arcBaseTime = (arc) => arc.edge.length / toblerSpeed(arcSlope(arc));

/**
 * Per-crisis cost context: which edges are removed and the soft multipliers per edge.
 * hazards: [{id, category, severity|null, lat, lng}] (ACTIVE only). loads: Map edgeId -> workers on it.
 */
export function buildCostContext(graph, { hazards = [], blockedEdgeIds = [] } = {}) {
  const blocked = new Set(blockedEdgeIds);
  const removed = new Set();
  const hazardMult = new Map();
  const reasons = new Map();
  const smokeOrGas = hazards.some((h) => h.category === 'FIRE_SMOKE' || h.category === 'GAS_LEAK');
  const addReason = (id, text) => reasons.set(id, [...(reasons.get(id) ?? []), text]);
  for (const e of graph.edges.values()) {
    if (e.blocked || blocked.has(e.id)) {
      removed.add(e.id);
      addReason(e.id, `${e.id} is blocked`);
      continue;
    }
    let mult = 1;
    for (const h of hazards) {
      let dMin = Infinity;
      for (let i = 1; i < e.coords.length; i += 1) dMin = Math.min(dMin, distPointSegment(h, e.coords[i - 1], e.coords[i]).d);
      const hard = (h.severity === 'CRITICAL') || (!h.severity && HARD_UNCLASSIFIED.has(h.category));
      if (hard && dMin <= HARD_RADIUS_M) {
        removed.add(e.id);
        addReason(e.id, `${e.id} is within ${HARD_RADIUS_M} m of a ${h.category.toLowerCase().replace('_', ' ')} hazard`);
        break;
      }
      if (dMin < SOFT_RADIUS_M) {
        mult *= 1 + (SEVERITY_W[h.severity ?? 'MEDIUM'] ?? 0.8) * (1 - dMin / SOFT_RADIUS_M);
        addReason(e.id, `Passes near a ${h.category.toLowerCase().replace('_', ' ')} hazard`);
      }
      if (h.category === 'FIRE_SMOKE' && dMin < FIRE_RADIUS_M) mult *= 1.6;
    }
    if (removed.has(e.id)) continue;
    if (smokeOrGas && e.airway === 'return') {
      mult *= 2.0;
      addReason(e.id, 'Return airway avoided (smoke or gas)');
    }
    if (e.widthM < 2.0) mult *= 1.2;
    hazardMult.set(e.id, mult);
  }
  return { removed, hazardMult, reasons };
}

/** Congestion multiplier from the current load on an edge. */
export const congestionMult = (edge, load = 0) => 1 + 0.5 * Math.max(0, load / edge.capacity - 1) ** 2;

/** Search cost of an arc: base time x hazard multiplier x congestion. Infinity when removed. */
export function arcCost(arc, ctx, loads) {
  if (ctx.removed.has(arc.edge.id)) return Infinity;
  return arcBaseTime(arc) * (ctx.hazardMult.get(arc.edge.id) ?? 1) * congestionMult(arc.edge, loads?.get(arc.edge.id) ?? 0);
}
