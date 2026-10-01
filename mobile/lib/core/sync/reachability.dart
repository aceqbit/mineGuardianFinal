import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../api/api_client.dart';

/// Connectivity is not internet: a connected radio is not a working path. The engine asks [canReachServer] first.
abstract class Reachability {
  /// Emits true when any network connection appears, false when none.
  Stream<bool> get connectivity$;
  Future<bool> hasConnection();

  /// GET /api/health with a 3 s timeout.
  Future<bool> canReachServer();
}

class ConnectivityReachability implements Reachability {
  ConnectivityReachability({required ApiClient api, Connectivity? connectivity}) : _api = api, _c = connectivity ?? Connectivity();
  final ApiClient _api;
  final Connectivity _c;

  static bool _has(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);

  @override
  Stream<bool> get connectivity$ => _c.onConnectivityChanged.map(_has);

  @override
  Future<bool> hasConnection() async => _has(await _c.checkConnectivity());

  @override
  Future<bool> canReachServer() => _api.health();
}
