// Shortest-path search: A*, Yen's K shortest loopless paths, route overlap. Pure.

class MinHeap {
  constructor() { this.a = []; }
  get size() { return this.a.length; }
  push(item, pri) {
    const a = this.a;
    a.push({ item, pri });
    let i = a.length - 1;
    while (i > 0) {
      const p = (i - 1) >> 1;
      if (a[p].pri <= a[i].pri) break;
      [a[p], a[i]] = [a[i], a[p]];
      i = p;
    }
  }
  pop() {
    const a = this.a;
    const top = a[0];
    const last = a.pop();
    if (a.length) {
      a[0] = last;
      let i = 0;
      for (;;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        if (l < a.length && a[l].pri < a[m].pri) m = l;
        if (r < a.length && a[r].pri < a[m].pri) m = r;
        if (m === i) break;
        [a[m], a[i]] = [a[i], a[m]];
        i = m;
      }
    }
    return top;
  }
}

const key = (from, to) => `${from}>${to}`;

/**
 * A* over a neighbour function: neighbors(node) -> [{to, cost, ...arc}]. heuristic must be admissible and consistent.
 * Returns {cost, nodes[], arcs[]} or null.
 */
export function aStar({ start, goal, neighbors, heuristic = () => 0, bannedNodes = new Set(), bannedArcs = new Set() }) {
  const g = new Map([[start, 0]]);
  const prev = new Map();
  const heap = new MinHeap();
  const closed = new Set();
  heap.push(start, heuristic(start));
  while (heap.size) {
    const { item: u } = heap.pop();
    if (closed.has(u)) continue;
    if (u === goal) {
      const nodes = [u];
      const arcs = [];
      for (let c = u; prev.has(c); c = prev.get(c).from) {
        nodes.unshift(prev.get(c).from);
        arcs.unshift(prev.get(c).arc);
      }
      return { cost: g.get(u), nodes, arcs };
    }
    closed.add(u);
    for (const arc of neighbors(u)) {
      if (!Number.isFinite(arc.cost) || bannedNodes.has(arc.to) || bannedArcs.has(key(u, arc.to))) continue;
      const ng = g.get(u) + arc.cost;
      if (ng < (g.get(arc.to) ?? Infinity)) {
        g.set(arc.to, ng);
        prev.set(arc.to, { from: u, arc });
        heap.push(arc.to, ng + heuristic(arc.to));
      }
    }
  }
  return null;
}

/** Yen's algorithm: up to k loopless shortest paths from start to goal, cheapest first. */
export function yen({ start, goal, neighbors, heuristic, k = 6 }) {
  const first = aStar({ start, goal, neighbors, heuristic });
  if (!first) return [];
  const found = [first];
  const candidates = [];
  const sameNodes = (a, b) => a.length === b.length && a.every((n, i) => n === b[i]);
  for (let n = 1; n < k; n += 1) {
    const last = found[n - 1];
    for (let i = 0; i < last.nodes.length - 1; i += 1) {
      const spur = last.nodes[i];
      const rootNodes = last.nodes.slice(0, i + 1);
      const rootArcs = last.arcs.slice(0, i);
      const bannedArcs = new Set();
      for (const p of found) if (p.nodes.length > i && sameNodes(p.nodes.slice(0, i + 1), rootNodes)) bannedArcs.add(key(p.nodes[i], p.nodes[i + 1]));
      const bannedNodes = new Set(rootNodes.slice(0, -1));
      const spurPath = aStar({ start: spur, goal, neighbors, heuristic, bannedNodes, bannedArcs });
      if (!spurPath) continue;
      const rootCost = rootArcs.reduce((s, a) => s + a.cost, 0);
      const total = { cost: rootCost + spurPath.cost, nodes: [...rootNodes.slice(0, -1), ...spurPath.nodes], arcs: [...rootArcs, ...spurPath.arcs] };
      if (!candidates.some((c) => sameNodes(c.nodes, total.nodes)) && !found.some((f) => sameNodes(f.nodes, total.nodes))) candidates.push(total);
    }
    if (!candidates.length) break;
    candidates.sort((a, b) => a.cost - b.cost);
    found.push(candidates.shift());
  }
  return found;
}

/** Share of `route` (length-weighted) that runs over edges already used by `other`. Routes: [{edgeId, len}]. */
export function overlapRatio(route, other) {
  const total = route.reduce((s, a) => s + a.len, 0);
  if (!total) return 0;
  const used = new Set(other.map((a) => a.edgeId));
  return route.filter((a) => used.has(a.edgeId)).reduce((s, a) => s + a.len, 0) / total;
}
