import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/location/location_service.dart';
import 'models/quality_report.dart';

class CheckinUploadResult {
  const CheckinUploadResult({required this.checkInId, required this.status});
  final String checkInId;
  final String status;
}

class CheckinRepository {
  CheckinRepository({required ApiClient api, LocationService? location}) : _api = api, _location = location ?? LocationService();
  final ApiClient _api;
  final LocationService _location;

  static String newClientId() => const Uuid().v4();

  Future<LocationFix?> currentLocation() => _location.getCurrent();

  /// Builds the multipart form. [queuedAt] is set only when the item went through the offline outbox.
  Future<FormData> buildForm({
    required QualityReport report,
    required int attempt,
    required String clientId,
    LocationFix? fix,
    DateTime? queuedAt,
  }) async {
    return FormData.fromMap({
      'image': MultipartFile.fromBytes(report.uploadBytes, filename: '$clientId.jpg', contentType: DioMediaType('image', 'jpeg')),
      'clientId': clientId,
      'capturedAt': report.capturedAt?.toUtc().toIso8601String() ?? '',
      'exifTakenAt': report.exifTakenAt?.toUtc().toIso8601String() ?? '',
      if (queuedAt != null) 'queuedAt': queuedAt.toUtc().toIso8601String(),
      'uploadStartedAt': DateTime.now().toUtc().toIso8601String(),
      'source': report.source,
      'attempt': '$attempt',
      if (fix != null) 'lat': '${fix.lat}',
      if (fix != null) 'lng': '${fix.lng}',
      if (fix != null) 'accuracyM': '${fix.accuracyM}',
      'sha256': report.sha256,
      'clientQuality': jsonEncode(report.metrics.toJson()),
    });
  }

  Future<CheckinUploadResult> upload({
    required QualityReport report,
    required int attempt,
    required String clientId,
    LocationFix? fix,
    void Function(double progress)? onProgress,
  }) async {
    final form = await buildForm(report: report, attempt: attempt, clientId: clientId, fix: fix);
    final res = await _api.postMultipart('/api/checkins', form, onProgress: (sent, total) {
      if (total > 0) onProgress?.call(sent / total);
    });
    final ci = (res['checkIn'] as Map).cast<String, dynamic>();
    return CheckinUploadResult(checkInId: (ci['id'] ?? ci['_id']).toString(), status: ci['status'] as String? ?? 'RECEIVED');
  }
}
