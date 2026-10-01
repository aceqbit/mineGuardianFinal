// Synthetic mine layout builder. Local metre grid (x east, y north) centred on the anchor.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { localToLatLng, pointInPolygon } from '../src/core/geo.js';

const XS = [-300, -180, -60, 60, 180, 300];

export const ZONE_RECTS = {
  'Z-A': { x: [-330, -110], y: [-150, 150] },
  'Z-B': { x: [-110, 110], y: [-150, 150] },
  'Z-C': { x: [110, 330], y: [-150, 150] },
};

export function buildLayout(anchor) {
  const nodes = {}; // id -> {x,y}
  for (let i = 0; i <= 10; i++) nodes[`J${i}`] = { x: -300 + i * 60, y: 0 };
  XS.forEach((x, i) => {
    nodes[`N${i}`] = { x, y: 120 };
    nodes[`S${i}`] = { x, y: -120 };
  });

  const ll = (n) => {
    const p = localToLatLng(anchor, n.x, n.y);
    return [p.lng, p.lat];
  };

  const features = [];
  const tunnels = [];
  const addTunnel = (from, to, widthM, capacity, slopePct, airway) => {
    const id = `T-${from}-${to}`;
    tunnels.push({ id, from, to });
    features.push({
      type: 'Feature',
      properties: { kind: 'tunnel', id, fromNode: from, toNode: to, widthM, capacity, slopePct, airway, status: 'open' },
      geometry: { type: 'LineString', coordinates: [ll(nodes[from]), ll(nodes[to])] },
    });
  };

  for (let i = 0; i < 10; i++) addTunnel(`J${i}`, `J${i + 1}`, 3.5, 20, 1.5, 'intake');
  for (let i = 0; i < 5; i++) addTunnel(`N${i}`, `N${i + 1}`, 2.8, 12, -1.0, 'return');
  for (let i = 0; i < 5; i++) addTunnel(`S${i}`, `S${i + 1}`, 2.8, 12, -1.0, 'return');
  XS.forEach((_x, i) => {
    const j = `J${i * 2}`;
    addTunnel(`N${i}`, j, 2.5, 10, 3.0, 'intake'); // north -> south
    addTunnel(j, `S${i}`, 2.5, 10, 3.0, 'intake');
  });

  for (const id of Object.keys(nodes)) {
    features.push({ type: 'Feature', properties: { kind: 'junction', id }, geometry: { type: 'Point', coordinates: ll(nodes[id]) } });
  }

  const exits = [
    { id: 'X-MAIN', name: 'Main Shaft', exitType: 'shaft', node: 'J0' },
    { id: 'X-INCL', name: 'Incline Adit', exitType: 'incline', node: 'N5' },
    { id: 'X-RET', name: 'Return Air Shaft', exitType: 'shaft', node: 'S2' },
  ];
  for (const ex of exits) {
    features.push({
      type: 'Feature',
      properties: { kind: 'exit', id: ex.id, name: ex.name, exitType: ex.exitType, node: ex.node },
      geometry: { type: 'Point', coordinates: ll(nodes[ex.node]) },
    });
  }
  features.push({
    type: 'Feature',
    properties: { kind: 'refuge', id: 'RC-1', name: 'Refuge Chamber RC-1', capacity: 25, node: 'J7' },
    geometry: { type: 'Point', coordinates: ll(nodes.J7) },
  });

  for (const [code, r] of Object.entries(ZONE_RECTS)) {
    const [x0, x1] = r.x;
    const [y0, y1] = r.y;
    const ring = [[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]].map(([x, y]) => ll({ x, y }));
    features.unshift({ type: 'Feature', properties: { kind: 'zone', code }, geometry: { type: 'Polygon', coordinates: [ring] } });
  }

  const geojson = { type: 'FeatureCollection', features };
  validateLayout(geojson, nodes, tunnels, exits);
  return geojson;
}

export function validateLayout(geojson, nodes, tunnels, exits) {
  const adj = new Map(Object.keys(nodes).map((k) => [k, []]));
  for (const t of tunnels) {
    adj.get(t.from).push(t.to);
    adj.get(t.to).push(t.from);
  }
  const reach = (start) => {
    const seen = new Set([start]);
    const q = [start];
    while (q.length) {
      const c = q.shift();
      for (const n of adj.get(c)) if (!seen.has(n)) (seen.add(n), q.push(n));
    }
    return seen;
  };
  const all = Object.keys(nodes);
  const first = reach(all[0]);
  if (first.size !== all.length) throw new Error('Layout invalid: graph is not connected');
  const exitNodes = new Set(exits.map((e) => e.node));
  for (const j of all) {
    const r = reach(j);
    const n = [...exitNodes].filter((x) => r.has(x)).length;
    if (n < 2) throw new Error(`Layout invalid: junction ${j} reaches fewer than 2 exits`);
  }
  for (const z of geojson.features.filter((f) => f.properties.kind === 'zone')) {
    const poly = z.geometry;
    const count = geojson.features.filter(
      (f) => f.properties.kind === 'junction' && pointInPolygon({ lng: f.geometry.coordinates[0], lat: f.geometry.coordinates[1] }, poly),
    ).length;
    if (count < 3) throw new Error(`Layout invalid: zone ${z.properties.code} has fewer than 3 junctions`);
  }
}

export function layoutStats(geojson) {
  const c = (k) => geojson.features.filter((f) => f.properties.kind === k).length;
  return { tunnels: c('tunnel'), junctions: c('junction'), exits: c('exit'), refuges: c('refuge'), zones: c('zone') };
}

// CLI: npm run layout
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const lat = Number(process.env.DEMO_ANCHOR_LAT ?? 23.746);
  const lng = Number(process.env.DEMO_ANCHOR_LNG ?? 86.415);
  const g = buildLayout({ lat, lng });
  const out = path.join(path.dirname(fileURLToPath(import.meta.url)), 'sample', 'mine_layout.geojson');
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, JSON.stringify(g, null, 2));
  const s = layoutStats(g);
  console.log(`Layout written to ${out}\nnodes=${s.junctions} edges=${s.tunnels} exits=${s.exits} refuges=${s.refuges} zones=${s.zones}`);
}
