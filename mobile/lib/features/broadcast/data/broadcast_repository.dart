import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../../../core/api/api_client.dart';

extension BroadcastPriorityLabel on BroadcastPriority {
  String get label => switch (this) { BroadcastPriority.info => 'Info', BroadcastPriority.urgent => 'Urgent', BroadcastPriority.emergency => 'Emergency' };
}

extension BroadcastScopeLabel on BroadcastScope {
  String get label => switch (this) { BroadcastScope.all => 'Everyone', BroadcastScope.zone => 'One zone', BroadcastScope.role => 'One role' };
}

BroadcastPriority _priority(String? w) {
  try {
    return BroadcastPriority.fromWire(w ?? 'INFO');
  } on ArgumentError {
    return BroadcastPriority.info;
  }
}

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toUtc();

class BroadcastMsg extends Equatable {
  const BroadcastMsg({required this.id, required this.text, required this.priority, required this.senderName, this.senderRole = '', this.createdAt, this.targets = 0, this.delivered = 0, this.read = 0, this.replies = 0});
  final String id, text, senderName, senderRole;
  final BroadcastPriority priority;
  final DateTime? createdAt;
  final int targets, delivered, read, replies;

  /// URGENT and EMERGENCY stay on screen until the person taps "Got it".
  bool get sticky => priority != BroadcastPriority.info;

  factory BroadcastMsg.fromJson(Map<String, dynamic> j) => BroadcastMsg(
        id: j['id'].toString(),
        text: j['text'] as String? ?? '',
        priority: _priority(j['priority'] as String?),
        senderName: j['senderName'] as String? ?? '',
        senderRole: j['senderRole'] as String? ?? '',
        createdAt: _dt(j['createdAt']),
        targets: (j['targets'] as num?)?.toInt() ?? 0,
        delivered: (j['delivered'] as num?)?.toInt() ?? 0,
        read: (j['read'] as num?)?.toInt() ?? 0,
        replies: (j['replies'] as num?)?.toInt() ?? 0,
      );

  BroadcastMsg withStats({int? targets, int? delivered, int? read, int? replies}) => BroadcastMsg(id: id, text: text, priority: priority, senderName: senderName, senderRole: senderRole, createdAt: createdAt, targets: targets ?? this.targets, delivered: delivered ?? this.delivered, read: read ?? this.read, replies: replies ?? this.replies);

  @override
  List<Object?> get props => [id, targets, delivered, read, replies];
}

class BroadcastReplyMsg extends Equatable {
  const BroadcastReplyMsg({required this.id, required this.userName, required this.text, this.broadcastId, this.at});
  final String id, userName, text;
  final String? broadcastId;
  final DateTime? at;
  factory BroadcastReplyMsg.fromJson(Map<String, dynamic> j) => BroadcastReplyMsg(id: j['id'].toString(), userName: j['userName'] as String? ?? '', text: j['text'] as String? ?? '', broadcastId: j['broadcastId']?.toString(), at: _dt(j['at']));
  @override
  List<Object?> get props => [id];
}

class BroadcastRepository {
  BroadcastRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<void> send({required String text, required BroadcastPriority priority, required BroadcastScope scope, String? zoneId, String? role}) =>
      _api.postJson('/api/broadcasts', body: {'text': text.trim(), 'priority': priority.wire, 'scope': scope.wire, 'zoneId': ?zoneId, 'role': ?role});

  Future<List<BroadcastMsg>> catchUp(DateTime? since) async =>
      (await _api.getList('/api/broadcasts', query: {'since': ?since?.toUtc().toIso8601String()})).map((e) => BroadcastMsg.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<List<BroadcastMsg>> history() async => (await _api.getList('/api/broadcasts/history')).map((e) => BroadcastMsg.fromJson((e as Map).cast<String, dynamic>())).toList();

  Future<List<BroadcastReplyMsg>> replies() async => (await _api.getList('/api/broadcasts/replies')).map((e) => BroadcastReplyMsg.fromJson((e as Map).cast<String, dynamic>())).toList();
}
