import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import 'models/quality_report.dart';

class HazardUploadResult {
  const HazardUploadResult({required this.hazardId});
  final String hazardId;
}

class HazardRepository {
  HazardRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  static String newClientId() => const Uuid().v4();

  Future<HazardUploadResult> upload({
    required QualityReport report,
    required HazardCategory category,
    required String clientId,
    LocationFix? fix,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(report.uploadBytes, filename: '$clientId.jpg', contentType: DioMediaType('image', 'jpeg')),
      'clientId': clientId,
      'category': category.wire,
      'capturedAt': report.capturedAt?.toUtc().toIso8601String() ?? '',
      'uploadStartedAt': DateTime.now().toUtc().toIso8601String(),
      if (fix != null) 'lat': '${fix.lat}',
      if (fix != null) 'lng': '${fix.lng}',
      if (fix != null) 'accuracyM': '${fix.accuracyM}',
      'sha256': report.sha256,
      'source': report.source,
    });
    final res = await _api.postMultipart('/api/hazards', form, onProgress: (s, t) {
      if (t > 0) onProgress?.call(s / t);
    });
    final h = (res['hazard'] as Map).cast<String, dynamic>();
    return HazardUploadResult(hazardId: (h['id'] ?? h['_id']).toString());
  }

  /// Open hazards for the offline evacuation map (supervisors/admins only; miners get a 403 -> empty).
  Future<List<dynamic>> openHazards() async {
    try {
      return await _api.getList('/api/hazards', query: {'status': 'OPEN', 'limit': 50});
    } on ApiException {
      return const [];
    }
  }
}
