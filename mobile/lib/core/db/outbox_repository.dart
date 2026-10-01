import 'package:sqflite/sqflite.dart';

import 'outbox_item.dart';

abstract class OutboxRepository {
  /// Idempotent on [OutboxItem.id]: enqueueing the same clientId twice keeps one row. Returns false when it already existed.
  Future<bool> enqueue(OutboxItem item);

  /// Pending items due now (nextAttemptAt <= now), ordered by priority then createdAt.
  Future<List<OutboxItem>> due(int nowMs);

  Future<List<OutboxItem>> all();
  Future<OutboxItem?> byId(String id);
  Future<void> update(OutboxItem item);
  Future<void> delete(String id);
  Future<int> countByStatus(OutboxStatus s);

  /// GPS rows keep only the 20 newest.
  Future<void> trimGps({int keep = 20});

  /// Items left in `sending` (app killed mid-send) go back to pending.
  Future<void> recoverSending();
}

class SqliteOutboxRepository implements OutboxRepository {
  SqliteOutboxRepository(this._db);
  final Database _db;

  @override
  Future<bool> enqueue(OutboxItem item) async {
    final id = await _db.insert('outbox', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    if (item.kind == OutboxKind.gps) await trimGps();
    return id != 0;
  }

  @override
  Future<List<OutboxItem>> due(int nowMs) async {
    final rows = await _db.query('outbox', where: "status = 'pending' AND next_attempt_at <= ?", whereArgs: [nowMs], orderBy: 'priority ASC, created_at ASC');
    return rows.map(OutboxItem.fromMap).toList();
  }

  @override
  Future<List<OutboxItem>> all() async => (await _db.query('outbox', orderBy: 'priority ASC, created_at ASC')).map(OutboxItem.fromMap).toList();

  @override
  Future<OutboxItem?> byId(String id) async {
    final rows = await _db.query('outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : OutboxItem.fromMap(rows.first);
  }

  @override
  Future<void> update(OutboxItem item) => _db.update('outbox', item.toMap(), where: 'id = ?', whereArgs: [item.id]);

  @override
  Future<void> delete(String id) => _db.delete('outbox', where: 'id = ?', whereArgs: [id]);

  @override
  Future<int> countByStatus(OutboxStatus s) async => Sqflite.firstIntValue(await _db.rawQuery('SELECT COUNT(*) FROM outbox WHERE status = ?', [s.name])) ?? 0;

  @override
  Future<void> trimGps({int keep = 20}) => _db.rawDelete("DELETE FROM outbox WHERE kind = 'gps' AND id NOT IN (SELECT id FROM outbox WHERE kind = 'gps' ORDER BY created_at DESC LIMIT ?)", [keep]);

  @override
  Future<void> recoverSending() => _db.update('outbox', {'status': 'pending'}, where: "status = 'sending'");
}
