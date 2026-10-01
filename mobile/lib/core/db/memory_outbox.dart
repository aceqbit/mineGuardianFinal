import 'dart:convert';

import 'cache_repository.dart';
import 'outbox_item.dart';
import 'outbox_repository.dart';

/// In-memory implementation behind the same interface (web, and unit tests).
class MemoryOutboxRepository implements OutboxRepository {
  final _items = <String, OutboxItem>{};

  int _cmp(OutboxItem a, OutboxItem b) {
    final p = a.priority.compareTo(b.priority);
    return p != 0 ? p : a.createdAt.compareTo(b.createdAt);
  }

  @override
  Future<bool> enqueue(OutboxItem item) async {
    if (_items.containsKey(item.id)) return false;
    _items[item.id] = item;
    if (item.kind == OutboxKind.gps) await trimGps();
    return true;
  }

  @override
  Future<List<OutboxItem>> due(int nowMs) async => (_items.values.where((i) => i.status == OutboxStatus.pending && i.nextAttemptAt <= nowMs).toList()..sort(_cmp));

  @override
  Future<List<OutboxItem>> all() async => (_items.values.toList()..sort(_cmp));

  @override
  Future<OutboxItem?> byId(String id) async => _items[id];

  @override
  Future<void> update(OutboxItem item) async {
    if (_items.containsKey(item.id)) _items[item.id] = item;
  }

  @override
  Future<void> delete(String id) async => _items.remove(id);

  @override
  Future<int> countByStatus(OutboxStatus s) async => _items.values.where((i) => i.status == s).length;

  @override
  Future<void> trimGps({int keep = 20}) async {
    final gps = _items.values.where((i) => i.kind == OutboxKind.gps).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    for (final old in gps.skip(keep)) {
      _items.remove(old.id);
    }
  }

  @override
  Future<void> recoverSending() async {
    for (final e in _items.entries.toList()) {
      if (e.value.status == OutboxStatus.sending) _items[e.key] = e.value.copyWith(status: OutboxStatus.pending);
    }
  }
}

class MemoryCacheRepository implements CacheRepository {
  final _map = <String, String>{};

  @override
  Future<Object?> read(String key) async => _map[key] == null ? null : jsonDecode(_map[key]!);

  @override
  Future<void> write(String key, Object? value) async => _map[key] = jsonEncode(value);

  @override
  Future<void> remove(String key) async => _map.remove(key);
}
