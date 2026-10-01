import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'cache_repository.dart';
import 'memory_outbox.dart';
import 'outbox_repository.dart';

/// Local persistence. SQLite on Android/iOS; an in-memory implementation behind the same interfaces on web.
class LocalDb {
  LocalDb._(this.outbox, this.cache);
  final OutboxRepository outbox;
  final CacheRepository cache;

  static const int version = 1;

  static Future<LocalDb> open() async {
    if (kIsWeb) return LocalDb._(MemoryOutboxRepository(), MemoryCacheRepository());
    try {
      final path = p.join(await getDatabasesPath(), 'mine_guardian.db');
      final db = await openDatabase(path, version: version, onCreate: _create);
      final outbox = SqliteOutboxRepository(db);
      await outbox.recoverSending();
      return LocalDb._(outbox, SqliteCacheRepository(db));
    } catch (_) {
      // Desktop or an unsupported platform: still usable, just not persistent.
      return LocalDb._(MemoryOutboxRepository(), MemoryCacheRepository());
    }
  }

  static Future<void> _create(Database db, int v) async {
    await db.execute('''
      CREATE TABLE outbox(
        id TEXT PRIMARY KEY,
        kind TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        file_path TEXT,
        priority INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        queued_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        status TEXT NOT NULL DEFAULT 'pending'
      )''');
    await db.execute('CREATE INDEX idx_outbox_drain ON outbox(status, priority, created_at)');
    await db.execute('''
      CREATE TABLE cache_kv(
        key TEXT PRIMARY KEY,
        value_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
  }

  /// For tests.
  static LocalDb memory() => LocalDb._(MemoryOutboxRepository(), MemoryCacheRepository());
}
