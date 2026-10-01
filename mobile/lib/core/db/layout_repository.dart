import 'package:dio/dio.dart';

import '../api/api_client.dart';
import '../models/mine_layout.dart';
import 'cache_repository.dart';

/// The layout (and the data the SOS screen needs) is cached in cache_kv so it works with zero connectivity.
class LayoutRepository {
  LayoutRepository({required ApiClient api, required CacheRepository cache}) : _api = api, _cache = cache;
  final ApiClient _api;
  final CacheRepository _cache;

  Future<MineLayoutData?> cached() async {
    final raw = await _cache.read(CacheKeys.layout);
    if (raw is! Map) return null;
    try {
      return MineLayoutData.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// Revalidates with `If-None-Match: <version>` so phones only download a new layout when the version changes.
  Future<MineLayoutData?> refresh() async {
    final cur = await _cache.read(CacheKeys.layout);
    final curVersion = cur is Map ? cur['version'] : null;
    try {
      final res = await _api.dio.get<dynamic>(
        '/api/layout',
        options: Options(headers: {if (curVersion != null) 'If-None-Match': '"$curVersion"'}, validateStatus: (s) => s == 200 || s == 304),
      );
      if (res.statusCode == 200 && res.data is Map) {
        await _cache.write(CacheKeys.layout, res.data);
        return MineLayoutData.fromJson((res.data as Map).cast<String, dynamic>());
      }
    } catch (_) {/* offline: keep the cached copy */}
    return cached();
  }

  Future<MineLayoutData?> load() async => await cached() ?? await refresh();

  Future<void> cacheProfile(Map<String, dynamic> profile) => _cache.write(CacheKeys.profile, profile);

  Future<void> cacheSupervisors(List<Map<String, dynamic>> sups) => _cache.write(CacheKeys.zoneSupervisors, sups);

  Future<List<Map<String, dynamic>>> cachedSupervisors() async {
    final raw = await _cache.read(CacheKeys.zoneSupervisors);
    return raw is List ? raw.map((e) => (e as Map).cast<String, dynamic>()).toList() : const [];
  }

  Future<void> cacheOpenHazards(List<dynamic> hazards) => _cache.write(CacheKeys.openHazards, hazards);

  Future<List<Map<String, dynamic>>> cachedOpenHazards() async {
    final raw = await _cache.read(CacheKeys.openHazards);
    return raw is List ? raw.map((e) => (e as Map).cast<String, dynamic>()).toList() : const [];
  }
}
