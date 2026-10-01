// Route computation for a crisis: candidates (Yen) -> diversity filter (<= 70% overlap) -> ranking. Pure.
import { haversineM } from '../../../core/geo.js';
import { REFUGE_PENALTY_S, VMAX, arcBaseTime, arcCost, buildCostContext, congestionMult, distPointSegment } from './graph.js';
import { aStar, overlapRatio, yen } from './search.js';

export const MAX_OVERLAP = 0.7;
export const SOS_ROUTES = 3;
export const OTHER_ROUTES = 2;
export const RANK_WEIGHTS = { eta: 0.55, risk: 0.3, congestion: 0.15 };

const norm = (x, min, max) => (max === min ? 0 : (x - min) / (max - min));

function snapToEdge(graph, p) {
  let best = null;
  for (const e of graph.edges.values()) {
    for (let i = 1; i < e.coords.length; i += 1) {
      const r = distPointSegment(p, e.coords[i - 1], e.coords[i]);
      if (!best || r.d < best.d) best = { edge: e, ...r };
    }
  }
  return best;
}

/** Heuristic: straight-line distance to the nearest exit or refuge at the best possible speed. Admissible and consistent. */
function makeHeuristic(graph, startPoint) {
  const targets = graph.targets.map((t) => graph.nodes.get(t.node));
  return (n) => {
    const p = n === 'START' ? startPoint : graph.nodes.get(n);
    if (!p) return 0;
    return Math.min(...targets.map((t) => haversineM(p, t))) / VMAX;
  };
}

function makeNeighbors(graph, ctx, loads, startArcs) {
  const targetAt = new Map();
  for (const t of graph.targets) targetAt.set(t.node, [...(targetAt.get(t.node) ?? []), t]);
  return (n) => {
    if (n === 'START') return startArcs;
    const out = [];
    for (const arc of graph.adj.get(n) ?? []) {
      const cost = arcCost(arc, ctx, loads);
      out.push({ to: arc.to, cost, info: { edgeId: arc.edge.id, len: arc.edge.length, baseTime: arcBaseTime(arc), hazard: ctx.hazardMult.get(arc.edge.id) ?? 1, cong: congestionMult(arc.edge, loads.get(arc.edge.id) ?? 0), coords: arc.forward ? arc.edge.coords : [...arc.edge.coords].reverse() } });
    }
    for (const t of targetAt.get(n) ?? []) {
      const pen = t.kind === 'refuge' ? REFUGE_PENALTY_S : 0;
      out.push({ to: 'SINK', cost: pen, info: { target: t, penalty: pen } });
      out.push({ to: `SINK:${t.id}`, cost: pen, info: { target: t, penalty: pen } });
    }
    return out;
  };
}

function startArcsFor(graph, ctx, loads, snap, point) {
  const { edge, t, proj } = snap;
  const mk = (to, fraction, forward, coords) => {
    const arc = { edge, forward };
    const base = arcBaseTime(arc) * fraction;
    const hazard = ctx.hazardMult.get(edge.id) ?? 1;
    const cong = congestionMult(edge, loads.get(edge.id) ?? 0);
    return { to, cost: base * hazard * cong, info: { edgeId: edge.id, len: edge.length * fraction, baseTime: base, hazard, cong, coords: [[point.lng, point.lat], [proj.lng, proj.lat], ...coords] } };
  };
  const fromC = graph.nodes.get(edge.from), toC = graph.nodes.get(edge.to);
  return [mk(edge.from, t, false, [[fromC.lng, fromC.lat]]), mk(edge.to, 1 - t, true, [[toC.lng, toC.lat]])];
}

function toRoute(path) {
  const body = path.arcs.filter((a) => a.info?.edgeId);
  const sink = path.arcs.find((a) => a.info?.target);
  const len = body.reduce((s, a) => s + a.info.len, 0) || 1;
  const coords = [];
  for (const a of body) for (const c of a.info.coords) if (!coords.length || coords[coords.length - 1][0] !== c[0] || coords[coords.length - 1][1] !== c[1]) coords.push(c);
  return {
    target: sink.info.target,
    edges: body.map((a) => ({ edgeId: a.info.edgeId, len: a.info.len })),
    distanceM: Math.round(len),
    etaSec: Math.round(body.reduce((s, a) => s + a.info.baseTime, 0) + sink.info.penalty),
    risk: +(body.reduce((s, a) => s + a.info.len * (a.info.hazard - 1), 0) / len).toFixed(3),
    congestion: +(body.reduce((s, a) => s + a.info.len * (a.info.cong - 1), 0) / len).toFixed(3),
    coords,
  };
}

/** Rank by 0.55*norm(eta) + 0.30*norm(risk) + 0.15*norm(congestion); lower is better. */
export function rankRoutes(routes) {
  if (!routes.length) return [];
  const ex = (k) => [Math.min(...routes.map((r) => r[k])), Math.max(...routes.map((r) => r[k]))];
  const [e0, e1] = ex('etaSec'), [r0, r1] = ex('risk'), [c0, c1] = ex('congestion');
  return routes
    .map((r) => ({ ...r, score: RANK_WEIGHTS.eta * norm(r.etaSec, e0, e1) + RANK_WEIGHTS.risk * norm(r.risk, r0, r1) + RANK_WEIGHTS.congestion * norm(r.congestion, c0, c1) }))
    .sort((a, b) => a.score - b.score || a.etaSec - b.etaSec);
}

/** Candidate routes for one start point: Yen (up to 6) then the best route to each exit, filtered for diversity. */
export function routesForPoint(graph, ctx, loads, point, want) {
  const snap = snapToEdge(graph, point);
  const startArcs = startArcsFor(graph, ctx, loads, snap, point);
  const neighbors = makeNeighbors(graph, ctx, loads, startArcs);
  const heuristic = makeHeuristic(graph, point);
  const candidates = yen({ start: 'START', goal: 'SINK', neighbors, heuristic, k: 6 }).map(toRoute);
  const accepted = [];
  const consider = (r) => {
    if (accepted.length >= want) return;
    if (accepted.every((a) => overlapRatio(r.edges, a.edges) <= MAX_OVERLAP) && !accepted.some((a) => a.target.id === r.target.id && overlapRatio(r.edges, a.edges) > MAX_OVERLAP)) accepted.push(r);
  };
  candidates.forEach(consider);
  if (accepted.length < want) {
    for (const t of graph.targets) {
      const p = aStar({ start: 'START', goal: `SINK:${t.id}`, neighbors, heuristic });
      if (p) consider(toRoute(p));
    }
  }
  return rankRoutes(accepted);
}

/**
 * workers: [{userId, name, lat, lng, positionUnknown}]. sosWorkerIds are processed first and get 3 routes; others get rank 1 + a backup.
 * Returns {collection (GeoJSON FeatureCollection), byWorker: {workerId: Feature[]}}.
 */
export function computeRoutes({ graph, workers, hazards = [], blockedEdgeIds = [], sosWorkerIds = [], crisisId = '', now = new Date() }) {
  const ctx = buildCostContext(graph, { hazards, blockedEdgeIds });
  const loads = new Map();
  const sos = new Set(sosWorkerIds.map(String));
  const ordered = [...workers].sort((a, b) => Number(sos.has(String(b.userId))) - Number(sos.has(String(a.userId))));
  const features = [];
  const byWorker = {};
  for (const w of ordered) {
    const isSos = sos.has(String(w.userId));
    const routes = routesForPoint(graph, ctx, loads, { lat: w.lat, lng: w.lng }, isSos ? SOS_ROUTES : OTHER_ROUTES);
    routes.forEach((r, i) => {
      const reasons = new Set();
      reasons.add(i === 0 ? 'Recommended: best balance of time, safety and crowding' : 'Backup route');
      if (r.target.kind === 'refuge') reasons.add('Refuge chamber: shelter in place (adds a 2 minute penalty)');
      for (const e of r.edges) for (const x of ctx.reasons.get(e.edgeId) ?? []) reasons.add(x);
      if (ctx.removed.size) reasons.add(`${ctx.removed.size} tunnel${ctx.removed.size > 1 ? 's' : ''} closed or too close to a hazard`);
      const feature = {
        type: 'Feature',
        properties: {
          crisisId: String(crisisId), workerId: String(w.userId), workerName: w.name ?? '', rank: i + 1, recommended: i === 0, exitId: r.target.id, exitName: r.target.name, exitType: r.target.exitType,
          distanceM: r.distanceM, etaSec: r.etaSec, risk: r.risk, congestion: r.congestion, reasons: [...reasons], positionUnknown: Boolean(w.positionUnknown), computedAt: now.toISOString(),
        },
        geometry: { type: 'LineString', coordinates: r.coords },
      };
      features.push(feature);
      (byWorker[String(w.userId)] ??= []).push(feature);
    });
    if (routes[0]) for (const e of routes[0].edges) loads.set(e.edgeId, (loads.get(e.edgeId) ?? 0) + 1);
  }
  return { collection: { type: 'FeatureCollection', features }, byWorker };
}
