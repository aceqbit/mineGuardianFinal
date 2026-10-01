import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';
import 'models/review_models.dart';

class ReviewRepository {
  ReviewRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<ReviewData> byCheckIn(String checkInId) async => ReviewData.fromJson(await _api.getJson('/api/compliance/reviews/by-checkin/$checkInId'));

  Future<void> decide(String reviewId, {required DecisionAction action, EscalationLevel? level, required Map<PpeKey, PpeStatus> items, String? note}) async {
    await _api.postJson('/api/compliance/reviews/$reviewId/decision', body: {
      'action': action.wire,
      if (level != null) 'escalationLevel': level.wire,
      'items': [for (final e in items.entries) {'key': e.key.wire, 'status': e.value.wire}],
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  Future<String> reportUrl(String reviewId) async => (await _api.getJson('/api/compliance/reviews/$reviewId/report-url'))['url'] as String;
}
