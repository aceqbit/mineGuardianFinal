// I.1: every contract route in lib/contracts/routes.dart must be registered by the router (or the phase 2 route list).
// Usage: dart run tool/route_check.dart   (exits 1 on any missing route)
import 'dart:io';

void main() {
  final routesSrc = File('lib/contracts/routes.dart').readAsStringSync();
  final registered = ['lib/app/router.dart', 'lib/phase2/phase2_routes.dart'].map((f) => File(f).readAsStringSync()).join('\n');
  final consts = RegExp(r"static const (\w+) = '(/[^']*)';").allMatches(routesSrc).map((m) => (name: m.group(1)!, path: m.group(2)!));
  // Not screens of their own: the evacuation shortcut is /worker/sos?mode=evac.
  const skip = {'workerSosEvac'};
  var failed = 0;
  for (final r in consts) {
    if (skip.contains(r.name)) continue;
    final ok = registered.contains('Routes.${r.name}');
    stdout.writeln('${ok ? 'PASS' : 'FAIL'}  ${r.path.padRight(34)} Routes.${r.name}');
    if (!ok) failed++;
  }
  // Placeholders must be gone: a route that renders "Coming in Phase 2" is not finished.
  final placeholder = registered.contains('Phase2Placeholder');
  stdout.writeln('${placeholder ? 'FAIL' : 'PASS'}  no placeholder screens remain');
  if (placeholder) failed++;
  stdout.writeln(failed == 0 ? '\nAll routes registered.' : '\n$failed problem(s).');
  exit(failed == 0 ? 0 : 1);
}
