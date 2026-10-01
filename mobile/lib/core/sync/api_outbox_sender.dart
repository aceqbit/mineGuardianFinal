import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../contracts/socket_events.dart';
import '../api/api_client.dart';
import '../db/outbox_item.dart';
import '../socket/socket_service.dart';
import 'sync_engine.dart';

/// Sends outbox items to the real API, always with the original clientId and the original queuedAt.
class ApiOutboxSender implements OutboxSender {
  ApiOutboxSender({required ApiClient api, required SocketService socket}) : _api = api, _socket = socket;
  final ApiClient _api;
  final SocketService _socket;

  Future<Uint8List> _bytes(OutboxItem i) async {
    if (i.memoryBytes != null) return i.memoryBytes!;
    if (!kIsWeb && i.filePath != null) return File(i.filePath!).readAsBytes();
    throw ApiException(code: 'MISSING_FILE', message: 'Queued photo is missing', statusCode: 400);
  }

  String? _s(Object? v) => v == null ? null : '$v';

  @override
  Future<Map<String, dynamic>> send(OutboxItem item) async {
    final p = item.payload;
    switch (item.kind) {
      case OutboxKind.checkin:
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(await _bytes(item), filename: '${item.id}.jpg', contentType: DioMediaType('image', 'jpeg')),
          'clientId': item.id,
          'capturedAt': _s(p['capturedAt']) ?? '',
          'exifTakenAt': _s(p['exifTakenAt']) ?? '',
          'queuedAt': item.queuedAt,
          'uploadStartedAt': DateTime.now().toUtc().toIso8601String(),
          'source': p['source'] ?? 'camera',
          'attempt': '${p['attempt'] ?? 1}',
          if (p['lat'] != null) 'lat': '${p['lat']}',
          if (p['lng'] != null) 'lng': '${p['lng']}',
          if (p['accuracyM'] != null) 'accuracyM': '${p['accuracyM']}',
          'sha256': p['sha256'],
          'clientQuality': jsonEncode(p['clientQuality'] ?? {}),
        });
        return _api.postMultipart('/api/checkins', form);
      case OutboxKind.hazard:
        final form = FormData.fromMap({
          'image': MultipartFile.fromBytes(await _bytes(item), filename: '${item.id}.jpg', contentType: DioMediaType('image', 'jpeg')),
          'clientId': item.id,
          'category': p['category'],
          'capturedAt': _s(p['capturedAt']) ?? '',
          'queuedAt': item.queuedAt,
          'uploadStartedAt': DateTime.now().toUtc().toIso8601String(),
          if (p['lat'] != null) 'lat': '${p['lat']}',
          if (p['lng'] != null) 'lng': '${p['lng']}',
          if (p['accuracyM'] != null) 'accuracyM': '${p['accuracyM']}',
          'sha256': p['sha256'],
          'source': p['source'] ?? 'camera',
        });
        return _api.postMultipart('/api/hazards', form);
      case OutboxKind.sos:
        return _api.postJson('/api/sos', body: {
          'clientId': item.id,
          if (p['lat'] != null) 'lat': p['lat'],
          if (p['lng'] != null) 'lng': p['lng'],
          if (p['accuracyM'] != null) 'accuracyM': p['accuracyM'],
          'triggeredAt': p['triggeredAt'],
        });
      case OutboxKind.sosCancel:
        return _api.postJson('/api/sos/${p['sosKey']}/cancel');
      case OutboxKind.gps:
        final ack = await _socket.emit(SocketEvents.gpsUpdate, Map<String, dynamic>.from(p));
        if (ack == null) throw ApiException(code: 'NETWORK', message: 'Socket not connected');
        return ack;
    }
  }
}
