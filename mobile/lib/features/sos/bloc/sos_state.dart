import 'package:equatable/equatable.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/mine_layout.dart';
import '../data/evac_graph.dart';

enum SosSendStatus { idle, sending, sent, savedOffline, failed }

/// One LineString feature of crisis:routes for this worker.
class ControlRoute extends Equatable {
  const ControlRoute({required this.rank, required this.points, required this.exitName, required this.etaSec, required this.recommended});
  final int rank;
  final List<GeoPoint> points;
  final String exitName;
  final double etaSec;
  final bool recommended;
  @override
  List<Object?> get props => [rank, points.length, exitName, etaSec, recommended];
}

class SosState extends Equatable {
  const SosState({
    this.evacOnly = false,
    this.status = SosSendStatus.idle,
    this.sentAt,
    this.retries = 0,
    this.layout,
    this.zoneCode,
    this.fix,
    this.offlineRoute,
    this.positionUnknown = false,
    this.controlRoutes = const [],
    this.assignedRank,
    this.cancelled = false,
    this.hazards = const [],
    this.sosId,
  });

  final bool evacOnly;
  final SosSendStatus status;
  final DateTime? sentAt;
  final int retries;
  final MineLayoutData? layout;
  final String? zoneCode;
  final LocationFix? fix;
  final EvacRoute? offlineRoute;
  final bool positionUnknown;
  final List<ControlRoute> controlRoutes;
  final int? assignedRank;
  final bool cancelled;
  final List<CachedHazard> hazards;
  final String? sosId;

  /// The route the control room wants this worker to take (assigned rank, else recommended).
  ControlRoute? get activeControlRoute {
    if (controlRoutes.isEmpty) return null;
    if (assignedRank != null) {
      final a = controlRoutes.where((r) => r.rank == assignedRank).firstOrNull;
      if (a != null) return a;
    }
    return controlRoutes.where((r) => r.recommended).firstOrNull ?? controlRoutes.first;
  }

  SosState copyWith({
    SosSendStatus? status,
    DateTime? sentAt,
    int? retries,
    MineLayoutData? layout,
    String? zoneCode,
    LocationFix? fix,
    EvacRoute? offlineRoute,
    bool clearOfflineRoute = false,
    bool? positionUnknown,
    List<ControlRoute>? controlRoutes,
    int? assignedRank,
    bool? cancelled,
    List<CachedHazard>? hazards,
    String? sosId,
  }) =>
      SosState(
        evacOnly: evacOnly,
        status: status ?? this.status,
        sentAt: sentAt ?? this.sentAt,
        retries: retries ?? this.retries,
        layout: layout ?? this.layout,
        zoneCode: zoneCode ?? this.zoneCode,
        fix: fix ?? this.fix,
        offlineRoute: clearOfflineRoute ? null : (offlineRoute ?? this.offlineRoute),
        positionUnknown: positionUnknown ?? this.positionUnknown,
        controlRoutes: controlRoutes ?? this.controlRoutes,
        assignedRank: assignedRank ?? this.assignedRank,
        cancelled: cancelled ?? this.cancelled,
        hazards: hazards ?? this.hazards,
        sosId: sosId ?? this.sosId,
      );

  SosState withEvacOnly(bool v) => SosState(
        evacOnly: v,
        status: status,
        sentAt: sentAt,
        retries: retries,
        layout: layout,
        zoneCode: zoneCode,
        fix: fix,
        offlineRoute: offlineRoute,
        positionUnknown: positionUnknown,
        controlRoutes: controlRoutes,
        assignedRank: assignedRank,
        cancelled: cancelled,
        hazards: hazards,
        sosId: sosId,
      );

  @override
  List<Object?> get props => [evacOnly, status, sentAt, retries, layout?.version, zoneCode, fix?.lat, fix?.lng, offlineRoute?.distanceM, positionUnknown, controlRoutes, assignedRank, cancelled, hazards.length, sosId];
}
