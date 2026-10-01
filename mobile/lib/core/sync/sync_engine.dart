import 'dart:async';
import 'dart:math' as math;

import 'package:rxdart/rxdart.dart';

import '../api/api_client.dart';
import '../db/outbox_item.dart';
import '../db/outbox_repository.dart';
import 'reachability.dart';
import 'sync_status.dart';

/// Sends one outbox item. Throws [ApiException]; a missing connection must surface as `isNetwork`.
abstract class OutboxSender {
  Future<Map<String, dynamic>> send(OutboxItem item);
}

/// Drains the outbox by priority, one item at a time, always with the same clientId (the server's idempotency key).
/// 2xx or 409 -> delete; 400/422 -> failed (no retry); 5xx / network -> retry after min(2^attempts, 300) s.
class SyncEngine {
  SyncEngine({required OutboxRepository outbox, required OutboxSender sender, required Reachability reachability, DateTime Function()? clock, this.tick = const Duration(seconds: 20), Future<void> Function(OutboxItem)? onRemoved})
      : _outbox = outbox,
        _sender = sender,
        _reach = reachability,
        _clock = clock ?? DateTime.now,
        _onRemoved = onRemoved;

  final OutboxRepository _outbox;
  final OutboxSender _sender;
  final Reachability _reach;
  final DateTime Function() _clock;
  final Duration tick;
  final Future<void> Function(OutboxItem)? _onRemoved;

  final _status = BehaviorSubject<SyncStatus>.seeded(const SyncStatus());
  final _results = PublishSubject<ItemResult>();
  StreamSubscription<bool>? _connSub;
  Timer? _tick;
  bool _draining = false;
  bool _again = false;
  bool _started = false;

  Stream<SyncStatus> get status$ => _status.stream;
  SyncStatus get status => _status.value;
  Stream<ItemResult> get itemResult$ => _results.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    _status.add(status.copyWith(online: await _reach.hasConnection()));
    _connSub = _reach.connectivity$.listen((on) {
      _status.add(status.copyWith(online: on));
      if (on) drain();
    });
    await _refreshCounts();
    unawaited(drain());
  }

  Future<void> stop() async {
    _started = false;
    await _connSub?.cancel();
    _connSub = null;
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _refreshCounts({bool clearSending = false}) async {
    final pending = await _outbox.countByStatus(OutboxStatus.pending);
    final sending = await _outbox.countByStatus(OutboxStatus.sending);
    final failed = await _outbox.countByStatus(OutboxStatus.failed);
    _status.add(status.copyWith(pendingCount: pending + sending, failedCount: failed, clearSending: clearSending));
    _syncTimer(pending + sending > 0);
  }

  /// The 20 s tick only runs while something is pending.
  void _syncTimer(bool hasPending) {
    if (hasPending && _started) {
      _tick ??= Timer.periodic(tick, (_) => drain());
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  /// Call after every enqueue, on connectivity change and on app resume.
  Future<void> drain() async {
    if (_draining) {
      _again = true;
      return;
    }
    _draining = true;
    try {
      do {
        _again = false;
        await _refreshCounts();
        if (status.pendingCount == 0) break;
        final reachable = await _reach.canReachServer();
        _status.add(status.copyWith(reachable: reachable));
        if (!reachable) break;
        var offlineDuringDrain = false;
        while (!offlineDuringDrain) {
          final due = await _outbox.due(_clock().millisecondsSinceEpoch);
          if (due.isEmpty) break;
          offlineDuringDrain = !await _sendOne(due.first);
        }
        if (offlineDuringDrain) _status.add(status.copyWith(reachable: false));
      } while (_again);
    } finally {
      _draining = false;
      await _refreshCounts(clearSending: true);
    }
  }

  /// Returns false when the network failed (stop draining).
  Future<bool> _sendOne(OutboxItem item) async {
    await _outbox.update(item.copyWith(status: OutboxStatus.sending));
    _status.add(status.copyWith(sendingKind: item.kind));
    try {
      final res = await _sender.send(item);
      await _remove(item);
      _status.add(status.copyWith(lastSyncedAt: _clock()));
      _results.add(ItemResult(id: item.id, kind: item.kind, success: true, response: res));
      await _refreshCounts();
      return true;
    } on ApiException catch (e) {
      final code = e.statusCode;
      if (code == 409) {
        await _remove(item); // duplicate: the server already has it
        _results.add(ItemResult(id: item.id, kind: item.kind, success: true, response: const {'duplicate': true}));
        await _refreshCounts();
        return true;
      }
      if (code == 400 || code == 422) {
        await _outbox.update(item.copyWith(status: OutboxStatus.failed, lastError: '${e.code}: ${e.message}', attempts: item.attempts + 1));
        _results.add(ItemResult(id: item.id, kind: item.kind, success: false, error: e.message));
        await _refreshCounts();
        return true;
      }
      final attempts = item.attempts + 1;
      final delaySec = math.min(math.pow(2, attempts).toInt(), 300);
      await _outbox.update(item.copyWith(status: OutboxStatus.pending, attempts: attempts, nextAttemptAt: _clock().millisecondsSinceEpoch + delaySec * 1000, lastError: e.message));
      await _refreshCounts();
      return !(e.isNetwork || code == null);
    } catch (e) {
      final attempts = item.attempts + 1;
      await _outbox.update(item.copyWith(status: OutboxStatus.pending, attempts: attempts, nextAttemptAt: _clock().millisecondsSinceEpoch + math.min(math.pow(2, attempts).toInt(), 300) * 1000, lastError: '$e'));
      await _refreshCounts();
      return false;
    }
  }

  Future<void> _remove(OutboxItem item) async {
    await _outbox.delete(item.id);
    await _onRemoved?.call(item);
  }

  /// "Retry now": clears backoff and failed state, then drains.
  Future<void> retryNow(String id) async {
    final it = await _outbox.byId(id);
    if (it == null) return;
    await _outbox.update(it.copyWith(status: OutboxStatus.pending, nextAttemptAt: 0, attempts: 0));
    await drain();
  }

  /// Discard needs confirmation in the UI; SOS items cannot be discarded.
  Future<bool> discard(String id) async {
    final it = await _outbox.byId(id);
    if (it == null) return false;
    if (it.kind == OutboxKind.sos || it.kind == OutboxKind.sosCancel) return false;
    await _remove(it);
    await _refreshCounts();
    return true;
  }

  Future<List<OutboxItem>> items() => _outbox.all();

  Future<void> dispose() async {
    await stop();
    await _status.close();
    await _results.close();
  }
}
