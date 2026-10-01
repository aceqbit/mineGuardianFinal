import 'package:equatable/equatable.dart';

import '../db/outbox_item.dart';

class SyncStatus extends Equatable {
  const SyncStatus({this.online = true, this.reachable = true, this.pendingCount = 0, this.sendingKind, this.lastSyncedAt, this.failedCount = 0});
  final bool online;
  final bool reachable;
  final int pendingCount;
  final OutboxKind? sendingKind;
  final DateTime? lastSyncedAt;
  final int failedCount;

  bool get isSyncing => sendingKind != null;
  bool get isOffline => !online || !reachable;

  SyncStatus copyWith({bool? online, bool? reachable, int? pendingCount, OutboxKind? sendingKind, bool clearSending = false, DateTime? lastSyncedAt, int? failedCount}) => SyncStatus(
        online: online ?? this.online,
        reachable: reachable ?? this.reachable,
        pendingCount: pendingCount ?? this.pendingCount,
        sendingKind: clearSending ? null : (sendingKind ?? this.sendingKind),
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        failedCount: failedCount ?? this.failedCount,
      );

  @override
  List<Object?> get props => [online, reachable, pendingCount, sendingKind, lastSyncedAt, failedCount];
}

/// Result of one outbox item, so the ticker can finish a queued check-in later.
class ItemResult {
  const ItemResult({required this.id, required this.kind, required this.success, this.response, this.error});
  final String id;
  final OutboxKind kind;
  final bool success;
  final Map<String, dynamic>? response;
  final String? error;
}
