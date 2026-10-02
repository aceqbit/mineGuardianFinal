import { AppError } from '../../../core/errors.js';
import { emitTo } from '../../../core/socket.js';
import { fromPoint } from '../../../core/geo.js';
import { Hazard } from '../../../models/Hazard.js';
import { MineLayout } from '../../../models/MineLayout.js';
import { User } from '../../../models/User.js';
import { Zone } from '../../../models/Zone.js';
import { buildCostContext, buildGraph } from './graph.js';
import { computeRoutes, routesForPoint } from './compute.js';

let cached = null; // {version, graph}

/** Graph from the latest layout; reloaded only when the layout version changes. */
export async function loadGraph() {
  const layout = await MineLayout.findOne().sort({ version: -1 });
  if (!layout) throw new AppError(503, 'NO_LAYOUT', 'Mine layout is not loaded');
  if (!cached || cached.version !== layout.version) cached = { version: layout.version, graph: buildGraph(layout.geojson) };
  return cached.graph;
}

export const __resetGraphCache = () => { cached = null; };

/** Hazards that influence routing: everything still OPEN or ACKNOWLEDGED that has a location. */
async function activeHazards() {
  const hs = await Hazard.find({ status: { $in: ['OPEN', 'ACKNOWLEDGED'] }, 'location.coordinates.0': { $exists: true } });
  return hs.map((h) => ({ id: String(h._id), category: h.category, severity: h.ai?.severity ?? null, ...fromPoint(h.location) }));
}

/** Centre of a zone's junctions: where a worker with no GPS fix is assumed to be. */
function zoneFallback(graph, zoneId, zonesById) {
  const code = zonesById.get(String(zoneId));
  const poly = graph.zones.find((z) => z.code === code)?.geometry?.coordinates?.[0];
  if (!poly) return null;
  const pts = poly.slice(0, -1);
  return { lng: pts.reduce((s, p) => s + p[0], 0) / pts.length, lat: pts.reduce((s, p) => s + p[1], 0) / pts.length };
}

/** Called by the crisis engine. positions: the live GPS map values. */
export async function computeForCrisis({ crisis, positions }) {
  const [graph, hazards, miners] = await Promise.all([
    loadGraph(),
    activeHazards(),
    User.find({ role: 'miner', status: 'active', zoneId: { $in: crisis.zoneIds } }),
  ]);
  const zones = await Zone.find({ _id: { $in: crisis.zoneIds } });
  const zonesById = new Map(zones.map((z) => [String(z._id), z.code]));
  const posById = new Map(positions.map((p) => [String(p.userId), p]));
  const workers = [];
  for (const m of miners) {
    const p = posById.get(String(m._id));
    const fb = p ? null : zoneFallback(graph, m.zoneId, zonesById);
    if (!p && !fb) continue;
    workers.push({ userId: String(m._id), name: m.fullName, lat: p?.lat ?? fb.lat, lng: p?.lng ?? fb.lng, positionUnknown: !p });
  }
  const sosWorkerIds = positions.filter((p) => p.sosId).map((p) => String(p.userId));
  return computeRoutes({ graph, workers, hazards, blockedEdgeIds: crisis.blockedEdgeIds ?? [], sosWorkerIds, crisisId: String(crisis._id) });
}

/** Admin pushes a worker to a chosen exit: best route to that exit, delivered as crisis:route_assigned. */
export async function assignRoute({ crisis, workerId, exitId, by }) {
  const graph = await loadGraph();
  const target = graph.targets.find((t) => t.id === exitId);
  if (!target) throw new AppError(400, 'VALIDATION_ERROR', 'Unknown exit', [{ path: 'exitId', message: 'Unknown exit' }]);
  const worker = await User.findById(workerId);
  if (!worker || !crisis.zoneIds.map(String).includes(String(worker.zoneId))) throw new AppError(404, 'NOT_FOUND', 'Worker is not in this crisis');
  const hazards = await activeHazards();
  const { getPositions } = await import('../crisis.engine.js');
  const pos = getPositions().get(String(workerId));
  const zone = await Zone.findById(worker.zoneId);
  const point = pos ?? zoneFallback(graph, worker.zoneId, new Map([[String(zone._id), zone.code]]));
  const ctx = buildCostContext(graph, { hazards, blockedEdgeIds: crisis.blockedEdgeIds ?? [] });
  const routes = routesForPoint(graph, ctx, new Map(), { lat: point.lat, lng: point.lng }, 6).filter((r) => r.target.id === exitId);
  const best = routes[0];
  if (!best) throw new AppError(409, 'NO_ROUTE', 'No safe route to that exit right now');
  const feature = {
    type: 'Feature',
    properties: { crisisId: String(crisis._id), workerId: String(workerId), workerName: worker.fullName, rank: 1, recommended: true, assigned: true, exitId, exitName: target.name, exitType: target.exitType, distanceM: best.distanceM, etaSec: best.etaSec, risk: best.risk, congestion: best.congestion, reasons: ['Assigned by the control room'], positionUnknown: !pos, computedAt: new Date().toISOString() },
    geometry: { type: 'LineString', coordinates: best.coords },
  };
  emitTo([`user:${workerId}`], 'crisis:routes', { crisisId: String(crisis._id), geojson: { type: 'FeatureCollection', features: [feature] } });
  emitTo([`user:${workerId}`], 'crisis:route_assigned', { crisisId: String(crisis._id), workerId: String(workerId), rank: 1, exitName: target.name, assignedBy: by?.fullName ?? 'Control room' });
  return { ok: true, route: feature };
}
