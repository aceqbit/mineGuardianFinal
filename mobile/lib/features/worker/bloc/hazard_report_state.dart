import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../../../core/location/location_service.dart';
import '../data/models/quality_report.dart';
import 'checkin_flow_state.dart';

enum LocationStatus { loading, ready, unavailable }

class HazardReportState extends Equatable {
  const HazardReportState({
    this.report,
    this.gating = false,
    this.category,
    this.locationStatus = LocationStatus.loading,
    this.fix,
    this.zoneCode,
    this.submitting = false,
    this.flow,
  });

  final QualityReport? report;
  final bool gating;
  final HazardCategory? category;
  final LocationStatus locationStatus;
  final LocationFix? fix;
  final String? zoneCode;
  final bool submitting;

  /// Non-null once submit starts; drives the ticker.
  final CheckinFlowState? flow;

  bool get photoOk => report != null && report!.pass;
  bool get canSubmit => photoOk && category != null && !submitting && !gating;

  HazardReportState copyWith({
    QualityReport? report,
    bool clearReport = false,
    bool? gating,
    HazardCategory? category,
    LocationStatus? locationStatus,
    LocationFix? fix,
    bool clearFix = false,
    String? zoneCode,
    bool clearZone = false,
    bool? submitting,
    CheckinFlowState? flow,
    bool clearFlow = false,
  }) =>
      HazardReportState(
        report: clearReport ? null : (report ?? this.report),
        gating: gating ?? this.gating,
        category: category ?? this.category,
        locationStatus: locationStatus ?? this.locationStatus,
        fix: clearFix ? null : (fix ?? this.fix),
        zoneCode: clearZone ? null : (zoneCode ?? this.zoneCode),
        submitting: submitting ?? this.submitting,
        flow: clearFlow ? null : (flow ?? this.flow),
      );

  @override
  List<Object?> get props => [report, gating, category, locationStatus, fix?.lat, fix?.lng, zoneCode, submitting, flow];
}
