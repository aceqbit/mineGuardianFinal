import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/core/models/mine_layout.dart';
import 'package:mine_guardian/features/sos/data/evac_graph.dart';

import 'fixtures/layout_fixture.dart';

void main() {
  final layout = MineLayoutData.fromJson(jsonDecode(layoutFixtureJson) as Map<String, dynamic>);
  GeoPoint j(String id) => layout.junctions.firstWhere((x) => x.id == id).point;

  test('layout parses: 3 exits, 1 refuge, 3 zones, >= 30 tunnels', () {
    expect(layout.exits.length, 3);
    expect(layout.refuges.length, 1);
    expect(layout.zones.length, 3);
    expect(layout.tunnels.length, greaterThanOrEqualTo(30));
  });

  test('route from J5 reaches an exit', () {
    final g = EvacGraph.build(layout);
    final r = g.routeFrom(j('J5'))!;
    expect(layout.exits.map((e) => e.node), contains(r.nodes.last));
    expect(r.distanceM, greaterThan(0));
    expect(r.summary, startsWith('Go to '));
  });

  test('blocking the direct trunk edge yields a longer detour', () {
    final base = EvacGraph.build(layout).routeFrom(j('J5'))!;
    // block the trunk edge on the base route's first step
    final first = '${base.nodes[0]}-${base.nodes[1]}';
    final blockedId = layout.tunnels.firstWhere((t) => '${t.from}-${t.to}' == first || '${t.to}-${t.from}' == first).id;
    final detour = EvacGraph.build(layout, extraBlocked: {blockedId}).routeFrom(j('J5'))!;
    expect(detour.distanceM, greaterThan(base.distanceM));
  });

  test('a cached fire hazard on the route makes it avoid that junction', () {
    final base = EvacGraph.build(layout).routeFrom(j('J6'))!;
    expect(base.nodes.length, greaterThan(2));
    final mid = base.nodes[1];
    final midPoint = layout.junctions.firstWhere((x) => x.id == mid).point;
    final g = EvacGraph.build(layout, hazards: [CachedHazard(point: midPoint, category: 'FIRE_SMOKE', severity: 'CRITICAL')]);
    final r = g.routeFrom(j('J6'));
    expect(r, isNotNull);
    expect(r!.nodes, isNot(contains(mid)));
    expect(g.skipped, isNotEmpty);
  });

  test('zone detection and no-position fallback', () {
    expect(layout.zoneCodeAt(j('J5').lat, j('J5').lng), 'Z-B');
    final g = EvacGraph.build(layout);
    expect(g.routeFromZone('Z-B'), isNotNull);
  });

  test('walking ETA uses 1.1 m/s', () {
    final r = EvacGraph.build(layout).routeFrom(j('J5'))!;
    expect((r.etaSec - r.distanceM / 1.1).abs(), lessThan(0.001));
  });
}
