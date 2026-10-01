import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';
import 'models/feed_item.dart';

class FeedSnapshot {
  const FeedSnapshot({required this.zoneId, required this.zoneCode, required this.zoneName, required this.workers, required this.checkins, required this.hazards, required this.sos});
  final String zoneId;
  final String zoneCode;
  final String zoneName;
  final List<WorkerToday> workers;
  final List<CheckinFeed> checkins;
  final List<HazardFeed> hazards;
  final List<SosFeed> sos;
}

class FeedRepository {
  FeedRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<FeedSnapshot> snapshot({String? zoneId}) async {
    final j = await _api.getJson('/api/feed/supervisor', query: {'zoneId': ?zoneId});
    final z = (j['zone'] as Map).cast<String, dynamic>();
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => ((j[k] as List?) ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    return FeedSnapshot(
      zoneId: z['id'].toString(),
      zoneCode: z['code'] as String? ?? '',
      zoneName: z['name'] as String? ?? '',
      workers: list('workers', WorkerToday.fromJson),
      checkins: list('checkins', CheckinFeed.fromJson),
      hazards: list('hazards', HazardFeed.fromJson),
      sos: list('sos', SosFeed.fromJson),
    );
  }

  /// Phase 2 data: a 404 means "not available yet" -> empty map.
  Future<Map<String, RiskBand>> riskBands(String zoneId) async {
    try {
      final list = await _api.getList('/api/scores/zone/$zoneId');
      return {for (final e in list) (e as Map)['workerId'].toString(): RiskBand.fromWire(e['riskBand'] as String)};
    } on ApiException {
      return const {};
    } catch (_) {
      return const {};
    }
  }

  Future<HazardFeed> updateHazard(String id, HazardStatus status, {String? note}) async {
    final res = await _api.patchJson('/api/hazards/$id', body: {'status': status.wire, if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
    return HazardFeed.fromJson((res['hazard'] as Map).cast<String, dynamic>());
  }

  Future<HazardFeed?> hazardById(String id) async {
    final list = await _api.getList('/api/hazards', query: {'limit': 200});
    for (final e in list) {
      final h = HazardFeed.fromJson((e as Map).cast<String, dynamic>());
      if (h.id == id) return h;
    }
    return null;
  }
}
