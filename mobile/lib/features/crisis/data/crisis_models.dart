import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../../../core/models/mine_layout.dart';

DateTime? _dt(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toUtc();

class TimelineLine extends Equatable {
  const TimelineLine(this.at, this.text);
  final DateTime? at;
  final String text;
  factory TimelineLine.fromJson(Map<String, dynamic> j) => TimelineLine(_dt(j['at']), j['text'] as String? ?? '');
  @override
  List<Object?> get props => [at, text];
}

class CrisisInfo extends Equatable {
  const CrisisInfo({required this.id, required this.startedAt, required this.triggers, required this.zoneIds, this.reason = '', this.zoneCodes = const [], this.shareToken, this.timeline = const [], this.blockedEdgeIds = const [], this.sosIds = const []});
  final String id;
  final DateTime? startedAt;
  final List<String> triggers;
  final List<String> zoneIds;
  final String reason;
  final List<String> zoneCodes;
  final String? shareToken;
  final List<TimelineLine> timeline;
  final List<String> blockedEdgeIds;
  final List<String> sosIds;

  factory CrisisInfo.fromJson(Map<String, dynamic> j) => CrisisInfo(
        id: (j['crisisId'] ?? j['id']).toString(),
        startedAt: _dt(j['startedAt']),
        triggers: ((j['triggers'] as List?) ?? [if (j['trigger'] != null) j['trigger']]).map((t) => (t as Map)['type'].toString()).toList(),
        zoneIds: ((j['zoneIds'] as List?) ?? const []).map((e) => '$e').toList(),
        reason: j['reason'] as String? ?? '',
        zoneCodes: ((j['zoneCodes'] as List?) ?? const []).map((e) => '$e').toList(),
        shareToken: j['shareToken'] as String?,
        timeline: ((j['timeline'] as List?) ?? const []).map((e) => TimelineLine.fromJson((e as Map).cast<String, dynamic>())).toList(),
        blockedEdgeIds: ((j['blockedEdgeIds'] as List?) ?? const []).map((e) => '$e').toList(),
        sosIds: ((j['sosIds'] as List?) ?? const []).map((e) => '$e').toList(),
      );

  CrisisInfo copyWith({List<String>? triggers, List<String>? zoneIds, List<TimelineLine>? timeline, List<String>? blockedEdgeIds}) =>
      CrisisInfo(id: id, startedAt: startedAt, triggers: triggers ?? this.triggers, zoneIds: zoneIds ?? this.zoneIds, reason: reason, zoneCodes: zoneCodes, shareToken: shareToken, timeline: timeline ?? this.timeline, blockedEdgeIds: blockedEdgeIds ?? this.blockedEdgeIds, sosIds: sosIds);

  @override
  List<Object?> get props => [id, startedAt, triggers, zoneIds, reason, zoneCodes, shareToken, timeline, blockedEdgeIds, sosIds];
}

class CrisisPosition extends Equatable {
  const CrisisPosition({required this.userId, required this.name, required this.zoneId, required this.point, this.accuracyM, this.ts, this.sos = false});
  final String userId, name, zoneId;
  final GeoPoint point;
  final double? accuracyM;
  final DateTime? ts;
  final bool sos;
  factory CrisisPosition.fromJson(Map<String, dynamic> j) => CrisisPosition(
        userId: j['userId'].toString(),
        name: j['name'] as String? ?? '',
        zoneId: j['zoneId']?.toString() ?? '',
        point: GeoPoint((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        accuracyM: (j['accuracyM'] as num?)?.toDouble(),
        ts: _dt(j['ts']),
        sos: j['sosId'] != null,
      );
  @override
  List<Object?> get props => [userId, point, ts, sos];
}

class RosterRow extends Equatable {
  const RosterRow({required this.userId, required this.name, required this.employeeId, required this.zoneId, required this.status});
  final String userId, name, employeeId, zoneId;
  final AccountedStatus status;
  factory RosterRow.fromJson(Map<String, dynamic> j) => RosterRow(
        userId: j['userId'].toString(),
        name: j['name'] as String? ?? '',
        employeeId: j['employeeId'] as String? ?? '',
        zoneId: j['zoneId']?.toString() ?? '',
        status: AccountedStatus.fromWire(j['status'] as String? ?? 'UNKNOWN'),
      );
  RosterRow withStatus(AccountedStatus s) => RosterRow(userId: userId, name: name, employeeId: employeeId, zoneId: zoneId, status: s);
  @override
  List<Object?> get props => [userId, status];
}

class CrisisRoute extends Equatable {
  const CrisisRoute({required this.workerId, required this.workerName, required this.rank, required this.recommended, required this.exitId, required this.exitName, required this.exitType, required this.distanceM, required this.etaSec, required this.risk, required this.congestion, required this.reasons, required this.positionUnknown, required this.points});
  final String workerId, workerName, exitId, exitName, exitType;
  final int rank, distanceM, etaSec;
  final bool recommended, positionUnknown;
  final double risk, congestion;
  final List<String> reasons;
  final List<GeoPoint> points;

  static List<CrisisRoute> parseCollection(dynamic fc) {
    final feats = (fc is Map ? fc['features'] : null) as List? ?? const [];
    return feats.map((f) {
      final p = ((f as Map)['properties'] as Map).cast<String, dynamic>();
      final coords = ((f['geometry'] as Map)['coordinates'] as List).map((c) => GeoPoint.fromCoord(c as List)).toList();
      return CrisisRoute(
        workerId: p['workerId'].toString(),
        workerName: p['workerName'] as String? ?? '',
        rank: (p['rank'] as num?)?.toInt() ?? 1,
        recommended: p['recommended'] == true,
        exitId: p['exitId'] as String? ?? '',
        exitName: p['exitName'] as String? ?? '',
        exitType: p['exitType'] as String? ?? '',
        distanceM: (p['distanceM'] as num?)?.toInt() ?? 0,
        etaSec: (p['etaSec'] as num?)?.toInt() ?? 0,
        risk: (p['risk'] as num?)?.toDouble() ?? 0,
        congestion: (p['congestion'] as num?)?.toDouble() ?? 0,
        reasons: ((p['reasons'] as List?) ?? const []).map((e) => '$e').toList(),
        positionUnknown: p['positionUnknown'] == true,
        points: coords,
      );
    }).toList();
  }

  @override
  List<Object?> get props => [workerId, rank, exitId, etaSec, distanceM];
}

class ActiveCrisisData extends Equatable {
  const ActiveCrisisData({required this.active, this.crisis, this.roster = const [], this.positions = const [], this.routes = const []});
  final bool active;
  final CrisisInfo? crisis;
  final List<RosterRow> roster;
  final List<CrisisPosition> positions;
  final List<CrisisRoute> routes;

  factory ActiveCrisisData.fromJson(Map<String, dynamic> j) {
    if (j['active'] != true) return const ActiveCrisisData(active: false);
    return ActiveCrisisData(
      active: true,
      crisis: CrisisInfo.fromJson((j['crisis'] as Map).cast<String, dynamic>()),
      roster: ((j['roster'] as List?) ?? const []).map((e) => RosterRow.fromJson((e as Map).cast<String, dynamic>())).toList(),
      positions: ((j['positions'] as List?) ?? const []).map((e) => CrisisPosition.fromJson((e as Map).cast<String, dynamic>())).toList(),
      routes: CrisisRoute.parseCollection(j['routes']),
    );
  }

  @override
  List<Object?> get props => [active, crisis, roster, positions, routes];
}
