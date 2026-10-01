import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';

class SosSendResult {
  const SosSendResult({required this.sosId});
  final String sosId;
}

class SosRepository {
  SosRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  static String newClientId() => const Uuid().v4();

  static Map<String, dynamic> payload(LocationFix? fix, DateTime triggeredAt) => {
        if (fix != null) 'lat': fix.lat,
        if (fix != null) 'lng': fix.lng,
        if (fix != null) 'accuracyM': fix.accuracyM,
        'triggeredAt': triggeredAt.toUtc().toIso8601String(),
      };

  Future<SosSendResult> send({required String clientId, required LocationFix? fix, required DateTime triggeredAt}) async {
    final res = await _api.postJson('/api/sos', body: {'clientId': clientId, ...payload(fix, triggeredAt)});
    final sos = (res['sos'] as Map).cast<String, dynamic>();
    return SosSendResult(sosId: (sos['id'] ?? sos['_id']).toString());
  }

  Future<void> cancel(String sosKey) => _api.postJson('/api/sos/$sosKey/cancel');
}
