import 'dart:convert';
import 'dart:typed_data';

enum OutboxKind {
  sos('sos', 0),
  sosCancel('sos_cancel', 1),
  hazard('hazard', 2),
  checkin('checkin', 3),
  gps('gps', 4);

  const OutboxKind(this.wire, this.priority);
  final String wire;

  /// Lower drains first: SOS 0, SOS cancel 1, hazard 2, check-in 3, GPS 4.
  final int priority;

  static OutboxKind fromWire(String w) => values.firstWhere((k) => k.wire == w);

  String get label => switch (this) {
        OutboxKind.sos => 'SOS',
        OutboxKind.sosCancel => 'SOS cancel',
        OutboxKind.hazard => 'Hazard report',
        OutboxKind.checkin => 'Check-in',
        OutboxKind.gps => 'Location',
      };
}

enum OutboxStatus { pending, sending, failed }

class OutboxItem {
  OutboxItem({
    required this.id,
    required this.kind,
    required this.payload,
    this.filePath,
    this.memoryBytes,
    int? createdAt,
    String? queuedAt,
    this.attempts = 0,
    this.nextAttemptAt = 0,
    this.lastError,
    this.status = OutboxStatus.pending,
  })  : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch,
        queuedAt = queuedAt ?? DateTime.now().toUtc().toIso8601String();

  /// The client-generated idempotency key (clientId).
  final String id;
  final OutboxKind kind;
  final Map<String, dynamic> payload;
  final String? filePath;

  /// Web / memory outbox only: photo bytes are not persisted to disk there.
  final Uint8List? memoryBytes;
  final int createdAt;
  final String queuedAt;
  final int attempts;
  final int nextAttemptAt;
  final String? lastError;
  final OutboxStatus status;

  int get priority => kind.priority;

  OutboxItem copyWith({int? attempts, int? nextAttemptAt, String? lastError, OutboxStatus? status}) => OutboxItem(
        id: id,
        kind: kind,
        payload: payload,
        filePath: filePath,
        memoryBytes: memoryBytes,
        createdAt: createdAt,
        queuedAt: queuedAt,
        attempts: attempts ?? this.attempts,
        nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
        lastError: lastError ?? this.lastError,
        status: status ?? this.status,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.wire,
        'payload_json': jsonEncode(payload),
        'file_path': filePath,
        'priority': priority,
        'created_at': createdAt,
        'queued_at': queuedAt,
        'attempts': attempts,
        'next_attempt_at': nextAttemptAt,
        'last_error': lastError,
        'status': status.name,
      };

  factory OutboxItem.fromMap(Map<String, Object?> m) => OutboxItem(
        id: m['id']! as String,
        kind: OutboxKind.fromWire(m['kind']! as String),
        payload: (jsonDecode(m['payload_json']! as String) as Map).cast<String, dynamic>(),
        filePath: m['file_path'] as String?,
        createdAt: m['created_at']! as int,
        queuedAt: m['queued_at']! as String,
        attempts: m['attempts']! as int,
        nextAttemptAt: m['next_attempt_at']! as int,
        lastError: m['last_error'] as String?,
        status: OutboxStatus.values.firstWhere((s) => s.name == m['status']),
      );
}
