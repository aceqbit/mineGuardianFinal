import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';
import 'crisis_models.dart';

class CrisisRepository {
  CrisisRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<ActiveCrisisData> active() async => ActiveCrisisData.fromJson(await _api.getJson('/api/crisis/active'));

  Future<void> activate(List<String> zoneIds, String reason) => _api.postJson('/api/crisis/activate', body: {'zoneIds': zoneIds, 'reason': reason});

  Future<void> resolve(String id, {required bool falseAlarm, required String note, required bool allAccounted, required bool hazardsContained}) =>
      _api.postJson('/api/crisis/$id/resolve', body: {'falseAlarm': falseAlarm, 'note': note, 'checklist': {'allAccounted': allAccounted, 'hazardsContained': hazardsContained}});

  Future<void> setAccounted(String id, String workerId, AccountedStatus s) => _api.postJson('/api/crisis/$id/accounted', body: {'workerId': workerId, 'status': s.wire});

  Future<void> recompute(String id) => _api.postJson('/api/crisis/$id/recompute');

  Future<void> blockEdge(String id, String edgeId, bool blocked) async {
    await _api.patchJson('/api/crisis/$id/edges/$edgeId', body: {'blocked': blocked});
  }

  Future<void> assignRoute(String id, String workerId, String exitId) => _api.postJson('/api/crisis/$id/assign-route', body: {'workerId': workerId, 'exitId': exitId});

  /// Post-crisis report: `{report, url}`.
  Future<Map<String, dynamic>> report(String id) => _api.getJson('/api/crisis/$id/report');
}
