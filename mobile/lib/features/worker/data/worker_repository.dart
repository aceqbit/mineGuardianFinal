import '../../../core/api/api_client.dart';
import 'models/checkin_summary.dart';

class WorkerRepository {
  WorkerRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  /// Phase 2 data: a 404 or a network error means "not available yet" -> null (never invented numbers).
  Future<WorkerStats?> stats() async {
    try {
      return WorkerStats.fromJson(await _api.getJson('/api/leaderboard/me'));
    } on ApiException {
      return null;
    }
  }

  /// A 404 is treated as empty until the endpoint exists.
  Future<List<CheckinSummary>> recent({int limit = 10}) async {
    try {
      final list = await _api.getList('/api/checkins/mine', query: {'limit': limit});
      return list.map((e) => CheckinSummary.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 404) return const [];
      rethrow;
    }
  }
}
