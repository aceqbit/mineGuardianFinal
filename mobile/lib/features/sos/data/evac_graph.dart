import 'dart:math' as math;

import '../../../core/models/mine_layout.dart';

/// Walking speed used for ETA (m/s).
const double walkSpeedMps = 1.1;

/// Hazard categories that make nearby tunnels unusable for the offline route.
const _blockingCategories = {'FIRE_SMOKE', 'FLOODING', 'ROOF_FALL'};
const double hazardAvoidRadiusM = 25;

class CachedHazard {
  const CachedHazard({required this.point, required this.category, this.severity});
  final GeoPoint point;
  final String category;
  final String? severity;

  bool get blocking => severity == 'CRITICAL' || _blockingCategories.contains(category);

  static CachedHazard? fromJson(Map<String, dynamic> j) {
    final loc = (j['locationLatLng'] ?? j['location']) as Map?;
    double? lat, lng;
    if (loc != null && loc['lat'] != null) {
      lat = (loc['lat'] as num).toDouble();
      lng = (loc['lng'] as num).toDouble();
    } else if (loc != null && loc['coordinates'] is List) {
      lng = ((loc['coordinates'] as List)[0] as num).toDouble();
      lat = ((loc['coordinates'] as List)[1] as num).toDouble();
    }
    if (lat == null || lng == null) return null;
    final ai = j['ai'] as Map?;
    return CachedHazard(point: GeoPoint(lat, lng), category: j['category'] as String? ?? 'OTHER', severity: ai?['severity'] as String?);
  }
}

class EvacRoute {
  const EvacRoute({required this.exit, required this.nodes, required this.points, required this.distanceM});
  final LayoutExit exit;
  final List<String> nodes;
  final List<GeoPoint> points;
  final double distanceM;

  double get etaSec => distanceM / walkSpeedMps;
  int get etaMin => math.max(1, (etaSec / 60).ceil());
  String get summary => 'Go to ${exit.name} · ${distanceM.round()} m · ~$etaMin min';
}

double _distToSegmentM(GeoPoint p, GeoPoint a, GeoPoint b) {
  // local equirectangular projection around p
  final k = 111320.0;
  final cosLat = math.cos(p.lat * math.pi / 180);
  double x(GeoPoint q) => (q.lng - p.lng) * k * cosLat;
  double y(GeoPoint q) => (q.lat - p.lat) * k;
  final ax = x(a), ay = y(a), bx = x(b), by = y(b);
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((-ax) * dx + (-ay) * dy) / len2).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt(cx * cx + cy * cy);
}

class EvacGraph {
  EvacGraph._(this.layout, this._adj, this._nodePoint, this.skipped);

  final MineLayoutData layout;
  final Map<String, List<(String, double, String)>> _adj; // node -> (neighbour, lengthM, tunnelId)
  final Map<String, GeoPoint> _nodePoint;

  /// Tunnel ids left out of the graph (blocked or near a dangerous cached hazard).
  final Set<String> skipped;

  /// Builds the graph. Tunnels that are blocked, or lie within 25 m of a cached CRITICAL / FIRE_SMOKE / FLOODING / ROOF_FALL hazard, are skipped.
  factory EvacGraph.build(MineLayoutData layout, {List<CachedHazard> hazards = const [], Set<String> extraBlocked = const {}}) {
    final adj = <String, List<(String, double, String)>>{};
    final pts = {for (final j in layout.junctions) j.id: j.point};
    for (final j in layout.junctions) {
      adj[j.id] = [];
    }
    final skipped = <String>{};
    final dangerous = hazards.where((h) => h.blocking).toList();
    for (final t in layout.tunnels) {
      var bad = t.blocked || extraBlocked.contains(t.id);
      if (!bad) {
        for (final h in dangerous) {
          for (var i = 1; i < t.coords.length; i++) {
            if (_distToSegmentM(h.point, t.coords[i - 1], t.coords[i]) <= hazardAvoidRadiusM) {
              bad = true;
              break;
            }
          }
          if (bad) break;
        }
      }
      if (bad) {
        skipped.add(t.id);
        continue;
      }
      final len = t.lengthM;
      adj.putIfAbsent(t.from, () => []).add((t.to, len, t.id));
      adj.putIfAbsent(t.to, () => []).add((t.from, len, t.id));
    }
    return EvacGraph._(layout, adj, pts, skipped);
  }

  /// Nearest junction id to a point.
  String? nearestJunction(GeoPoint p) {
    String? best;
    var bestD = double.infinity;
    for (final e in _nodePoint.entries) {
      final d = haversineM(p, e.value);
      if (d < bestD) {
        bestD = d;
        best = e.key;
      }
    }
    return best;
  }

  /// Dijkstra from [start] to every exit; returns the shortest reachable route, or null.
  EvacRoute? shortestToExit(String start) {
    final dist = <String, double>{start: 0};
    final prev = <String, String>{};
    final done = <String>{};
    final open = <String>{start};
    while (open.isNotEmpty) {
      final u = open.reduce((a, b) => (dist[a] ?? double.infinity) <= (dist[b] ?? double.infinity) ? a : b);
      open.remove(u);
      if (!done.add(u)) continue;
      for (final (v, w, _) in _adj[u] ?? const <(String, double, String)>[]) {
        final nd = dist[u]! + w;
        if (nd < (dist[v] ?? double.infinity)) {
          dist[v] = nd;
          prev[v] = u;
          open.add(v);
        }
      }
    }
    LayoutExit? bestExit;
    var bestD = double.infinity;
    for (final ex in layout.exits) {
      final d = dist[ex.node];
      if (d != null && d < bestD) {
        bestD = d;
        bestExit = ex;
      }
    }
    if (bestExit == null) return null;
    final nodes = <String>[bestExit.node];
    while (nodes.first != start) {
      nodes.insert(0, prev[nodes.first]!);
    }
    return EvacRoute(exit: bestExit, nodes: nodes, points: [for (final n in nodes) _nodePoint[n]!], distanceM: bestD);
  }

  /// Route from a GPS position (snapped to the nearest junction).
  EvacRoute? routeFrom(GeoPoint position) {
    final n = nearestJunction(position);
    return n == null ? null : shortestToExit(n);
  }

  /// With no position: from the junction nearest the zone centroid.
  EvacRoute? routeFromZone(String zoneCode) {
    final zone = layout.zones.where((z) => z.code == zoneCode).firstOrNull;
    if (zone == null) return null;
    final ring = zone.ring;
    final lat = ring.map((p) => p.lat).reduce((a, b) => a + b) / ring.length;
    final lng = ring.map((p) => p.lng).reduce((a, b) => a + b) / ring.length;
    return routeFrom(GeoPoint(lat, lng));
  }
}
