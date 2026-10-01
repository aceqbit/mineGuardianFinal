import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/outbox_item.dart';
import '../db/outbox_repository.dart';
import 'sync_engine.dart';

/// Facade used by repositories: persist (photo copied to the documents dir, since the OS can purge temp files),
/// enqueue, then nudge the engine.
class OutboxQueue {
  OutboxQueue({required OutboxRepository outbox, required SyncEngine engine}) : _outbox = outbox, _engine = engine;
  final OutboxRepository _outbox;
  final SyncEngine _engine;

  Future<String?> _persistPhoto(String id, Uint8List bytes) async {
    if (kIsWeb) return null;
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'outbox'));
    await dir.create(recursive: true);
    final f = File(p.join(dir.path, '$id.jpg'));
    await f.writeAsBytes(bytes, flush: true);
    return f.path;
  }

  /// Removes the persisted photo when its row is gone.
  static Future<void> deleteFile(OutboxItem item) async {
    final path = item.filePath;
    if (path == null || kIsWeb) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<bool> _enqueue(OutboxItem item) async {
    final added = await _outbox.enqueue(item);
    _engine.drain();
    return added;
  }

  Future<bool> enqueueCheckin({required String clientId, required Uint8List photo, required Map<String, dynamic> payload}) async {
    final path = await _persistPhoto(clientId, photo);
    return _enqueue(OutboxItem(id: clientId, kind: OutboxKind.checkin, payload: payload, filePath: path, memoryBytes: path == null ? photo : null));
  }

  Future<bool> enqueueHazard({required String clientId, required Uint8List photo, required Map<String, dynamic> payload}) async {
    final path = await _persistPhoto(clientId, photo);
    return _enqueue(OutboxItem(id: clientId, kind: OutboxKind.hazard, payload: payload, filePath: path, memoryBytes: path == null ? photo : null));
  }

  Future<bool> enqueueSos({required String clientId, required Map<String, dynamic> payload}) => _enqueue(OutboxItem(id: clientId, kind: OutboxKind.sos, payload: payload));

  /// [sosKey] is the server id, or the SOS clientId if the SOS itself is still queued (the server accepts either).
  Future<bool> enqueueSosCancel({required String clientId, required String sosKey}) => _enqueue(OutboxItem(id: clientId, kind: OutboxKind.sosCancel, payload: {'sosKey': sosKey}));

  Future<bool> enqueueGps({required String clientId, required Map<String, dynamic> payload}) => _enqueue(OutboxItem(id: clientId, kind: OutboxKind.gps, payload: payload));
}
