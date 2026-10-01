import 'package:equatable/equatable.dart';

import '../../../core/api/api_client.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toUtc();

class SupervisorReliability extends Equatable {
  const SupervisorReliability({required this.id, required this.fullName, required this.zoneCode, required this.decided, required this.onTime, required this.breaches, required this.noData, required this.reliability});
  final String id, fullName, zoneCode;
  final int decided, onTime, breaches, reliability;
  final bool noData;
  factory SupervisorReliability.fromJson(Map<String, dynamic> j) => SupervisorReliability(
        id: j['id'].toString(),
        fullName: j['fullName'] as String? ?? '',
        zoneCode: j['zoneCode'] as String? ?? '',
        decided: (j['decided'] as num?)?.toInt() ?? 0,
        onTime: (j['onTime'] as num?)?.toInt() ?? 0,
        breaches: (j['breaches'] as num?)?.toInt() ?? 0,
        noData: j['noData'] == true,
        reliability: (j['reliability'] as num?)?.toInt() ?? 100,
      );
  @override
  List<Object?> get props => [id, reliability, breaches, decided];
}

class SlaReview extends Equatable {
  const SlaReview({required this.reviewId, required this.zoneCode, required this.workerName, this.dueAt, this.remindersSent = 0, this.breached = false, this.compensated = false, this.escalationAcked = false});
  final String reviewId, zoneCode, workerName;
  final DateTime? dueAt;
  final int remindersSent;
  final bool breached, compensated, escalationAcked;
  factory SlaReview.fromJson(Map<String, dynamic> j) => SlaReview(
        reviewId: j['reviewId'].toString(),
        zoneCode: j['zoneCode'] as String? ?? '',
        workerName: j['workerName'] as String? ?? '',
        dueAt: _dt(j['dueAt']),
        remindersSent: (j['remindersSent'] as num?)?.toInt() ?? 0,
        breached: j['breached'] == true,
        compensated: j['compensated'] == true,
        escalationAcked: j['escalationAcked'] == true,
      );
  @override
  List<Object?> get props => [reviewId, breached, compensated, escalationAcked];
}

class SlaOverview extends Equatable {
  const SlaOverview({this.supervisors = const [], this.breaches = const [], this.escalations = const [], this.pending = 0});
  final List<SupervisorReliability> supervisors;
  final List<SlaReview> breaches, escalations;
  final int pending;
  factory SlaOverview.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => ((j[k] as List?) ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();
    return SlaOverview(supervisors: list('supervisors', SupervisorReliability.fromJson), breaches: list('breaches', SlaReview.fromJson), escalations: list('escalations', SlaReview.fromJson), pending: (j['pending'] as num?)?.toInt() ?? 0);
  }
  @override
  List<Object?> get props => [supervisors, breaches, escalations, pending];
}

class HazardAuditRow extends Equatable {
  const HazardAuditRow({required this.id, required this.category, required this.severity, required this.status, required this.zoneCode, required this.reporter, this.createdAt, this.ackMinutes, this.closeMinutes, this.slow = false});
  final String id, category, status, zoneCode, reporter;
  final String? severity;
  final DateTime? createdAt;
  final int? ackMinutes, closeMinutes;
  final bool slow;
  factory HazardAuditRow.fromJson(Map<String, dynamic> j) => HazardAuditRow(
        id: j['id'].toString(),
        category: j['category'] as String? ?? '',
        severity: j['severity'] as String?,
        status: j['status'] as String? ?? '',
        zoneCode: j['zoneCode'] as String? ?? '',
        reporter: j['reporter'] as String? ?? '',
        createdAt: _dt(j['createdAt']),
        ackMinutes: (j['ackMinutes'] as num?)?.toInt(),
        closeMinutes: (j['closeMinutes'] as num?)?.toInt(),
        slow: j['slow'] == true,
      );
  @override
  List<Object?> get props => [id, status, ackMinutes, closeMinutes];
}

class HazardAudit extends Equatable {
  const HazardAudit({this.total = 0, this.byStatus = const {}, this.medianAckMinutes, this.slowOpen = 0, this.hazards = const []});
  final int total, slowOpen;
  final Map<String, int> byStatus;
  final int? medianAckMinutes;
  final List<HazardAuditRow> hazards;
  factory HazardAudit.fromJson(Map<String, dynamic> j) => HazardAudit(
        total: (j['total'] as num?)?.toInt() ?? 0,
        byStatus: ((j['byStatus'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as num).toInt())),
        medianAckMinutes: (j['medianAckMinutes'] as num?)?.toInt(),
        slowOpen: (j['slowOpen'] as num?)?.toInt() ?? 0,
        hazards: ((j['hazards'] as List?) ?? const []).map((e) => HazardAuditRow.fromJson((e as Map).cast<String, dynamic>())).toList(),
      );
  @override
  List<Object?> get props => [total, byStatus, medianAckMinutes, slowOpen, hazards];
}

class ReportRow extends Equatable {
  const ReportRow({required this.id, required this.day, this.compliancePct, this.reviewed = 0, this.auto = false});
  final String id, day;
  final int? compliancePct;
  final int reviewed;
  final bool auto;
  factory ReportRow.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    return ReportRow(id: (j['id'] ?? j['_id']).toString(), day: j['day'] as String? ?? '', compliancePct: (s['compliancePct'] as num?)?.toInt(), reviewed: (s['reviewed'] as num?)?.toInt() ?? 0, auto: j['auto'] == true);
  }
  @override
  List<Object?> get props => [id, day];
}

class AdminNormalRepository {
  AdminNormalRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  Future<SlaOverview> sla() async => SlaOverview.fromJson(await _api.getJson('/api/admin/sla'));
  Future<HazardAudit> hazardAudit({int days = 7}) async => HazardAudit.fromJson(await _api.getJson('/api/admin/hazard-audit', query: {'days': days}));
  Future<void> compensate(String reviewId, {required bool approve, required String note}) => _api.postJson('/api/admin/compensation/$reviewId', body: {'approve': approve, 'note': note});
  Future<void> ackEscalation(String reviewId) => _api.postJson('/api/admin/escalations/$reviewId/ack');
  Future<List<ReportRow>> reports() async => (await _api.getList('/api/admin/reports')).map((e) => ReportRow.fromJson((e as Map).cast<String, dynamic>())).toList();
  Future<void> generateReport({String? day}) => _api.postJson('/api/admin/reports/generate', body: {'day': ?day});
  Future<String> reportUrl(String id) async => (await _api.getJson('/api/admin/reports/$id/url'))['url'] as String;
}
