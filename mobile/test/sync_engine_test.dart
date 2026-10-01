import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/db/memory_outbox.dart';
import 'package:mine_guardian/core/db/outbox_item.dart';
import 'package:mine_guardian/core/sync/reachability.dart';
import 'package:mine_guardian/core/sync/sync_engine.dart';
import 'package:mine_guardian/core/sync/sync_status.dart';

class _Reach implements Reachability {
  bool reachable = true;
  final _c = StreamController<bool>.broadcast();
  @override
  Stream<bool> get connectivity$ => _c.stream;
  @override
  Future<bool> hasConnection() async => reachable;
  @override
  Future<bool> canReachServer() async => reachable;
}

class _Sender implements OutboxSender {
  final sent = <String>[];
  final plan = <String, List<int?>>{}; // id -> status codes per call (null = network error, 200 = ok)
  @override
  Future<Map<String, dynamic>> send(OutboxItem item) async {
    sent.add(item.id);
    final codes = plan[item.id];
    final code = (codes != null && codes.isNotEmpty) ? codes.removeAt(0) : 200;
    if (code == 200) return {'ok': true};
    if (code == null) throw ApiException(code: 'NETWORK', message: 'offline');
    throw ApiException(code: 'HTTP_$code', message: 'err $code', statusCode: code);
  }
}

OutboxItem item(String id, OutboxKind k, {int created = 0}) => OutboxItem(id: id, kind: k, payload: const {}, createdAt: created);

void main() {
  late MemoryOutboxRepository outbox;
  late _Sender sender;
  late _Reach reach;
  late DateTime now;
  late SyncEngine engine;

  setUp(() {
    outbox = MemoryOutboxRepository();
    sender = _Sender();
    reach = _Reach();
    now = DateTime(2026, 1, 1, 12);
    engine = SyncEngine(outbox: outbox, sender: sender, reachability: reach, clock: () => now);
  });

  test('items drain in priority order (SOS, SOS cancel, hazard, check-in, GPS)', () async {
    await outbox.enqueue(item('gps', OutboxKind.gps, created: 1));
    await outbox.enqueue(item('checkin', OutboxKind.checkin, created: 2));
    await outbox.enqueue(item('hazard', OutboxKind.hazard, created: 3));
    await outbox.enqueue(item('cancel', OutboxKind.sosCancel, created: 4));
    await outbox.enqueue(item('sos', OutboxKind.sos, created: 5));
    await engine.drain();
    expect(sender.sent, ['sos', 'cancel', 'hazard', 'checkin', 'gps']);
    expect((await outbox.all()), isEmpty);
    expect(engine.status.lastSyncedAt, isNotNull);
  });

  test('a 500 is retried with exponential backoff, capped at 300 s', () async {
    await outbox.enqueue(item('a', OutboxKind.checkin));
    sender.plan['a'] = [500, 500, 200];
    await engine.drain();
    var it = (await outbox.byId('a'))!;
    expect(it.status, OutboxStatus.pending);
    expect(it.attempts, 1);
    expect(it.nextAttemptAt, now.millisecondsSinceEpoch + 2000);
    await engine.drain(); // not due yet
    expect(sender.sent.length, 1);
    now = now.add(const Duration(seconds: 3));
    await engine.drain();
    it = (await outbox.byId('a'))!;
    expect(it.attempts, 2);
    expect(it.nextAttemptAt, now.millisecondsSinceEpoch + 4000);
    now = now.add(const Duration(seconds: 5));
    await engine.drain();
    expect(await outbox.byId('a'), isNull);
    // cap
    await outbox.enqueue(OutboxItem(id: 'b', kind: OutboxKind.hazard, payload: const {}, attempts: 20));
    sender.plan['b'] = [503];
    await engine.drain();
    final b = (await outbox.byId('b'))!;
    expect(b.nextAttemptAt - now.millisecondsSinceEpoch, 300000);
  });

  test('a 422 fails and is not retried; 409 counts as success', () async {
    await outbox.enqueue(item('bad', OutboxKind.checkin));
    await outbox.enqueue(item('dup', OutboxKind.hazard));
    sender.plan['bad'] = [422];
    sender.plan['dup'] = [409];
    final results = <ItemResult>[];
    engine.itemResult$.listen(results.add);
    await engine.drain();
    await engine.drain();
    expect(sender.sent.where((s) => s == 'bad').length, 1);
    expect((await outbox.byId('bad'))!.status, OutboxStatus.failed);
    expect(await outbox.byId('dup'), isNull);
    expect(engine.status.failedCount, 1);
    await Future<void>.delayed(Duration.zero);
    expect(results.firstWhere((r) => r.id == 'dup').success, true);
    expect(results.firstWhere((r) => r.id == 'bad').success, false);
  });

  test('enqueueing the same clientId twice creates one row', () async {
    expect(await outbox.enqueue(item('x', OutboxKind.sos)), true);
    expect(await outbox.enqueue(item('x', OutboxKind.sos)), false);
    expect((await outbox.all()).length, 1);
  });

  test('nothing is sent while the server is unreachable; drains when reachable again', () async {
    await outbox.enqueue(item('a', OutboxKind.sos));
    reach.reachable = false;
    await engine.drain();
    expect(sender.sent, isEmpty);
    expect(engine.status.reachable, false);
    expect(engine.status.pendingCount, 1);
    reach.reachable = true;
    await engine.drain();
    expect(sender.sent, ['a']);
  });

  test('a network error stops the drain and keeps the row pending', () async {
    await outbox.enqueue(item('a', OutboxKind.sos, created: 1));
    await outbox.enqueue(item('b', OutboxKind.checkin, created: 2));
    sender.plan['a'] = [null];
    await engine.drain();
    expect(sender.sent, ['a']);
    expect((await outbox.byId('a'))!.status, OutboxStatus.pending);
    expect(engine.status.reachable, false);
  });

  test('GPS keeps only the 20 newest rows', () async {
    for (var i = 0; i < 30; i++) {
      await outbox.enqueue(item('g$i', OutboxKind.gps, created: i));
    }
    final all = await outbox.all();
    expect(all.length, 20);
    expect(all.any((e) => e.id == 'g29'), true);
    expect(all.any((e) => e.id == 'g0'), false);
  });

  test('SOS items cannot be discarded; retryNow clears backoff', () async {
    await outbox.enqueue(item('sos', OutboxKind.sos));
    await outbox.enqueue(item('c', OutboxKind.checkin));
    expect(await engine.discard('sos'), false);
    expect(await engine.discard('c'), true);
    sender.plan['sos'] = [500];
    await engine.drain();
    expect((await outbox.byId('sos'))!.nextAttemptAt, greaterThan(now.millisecondsSinceEpoch));
    await engine.retryNow('sos');
    expect(await outbox.byId('sos'), isNull);
  });
}
