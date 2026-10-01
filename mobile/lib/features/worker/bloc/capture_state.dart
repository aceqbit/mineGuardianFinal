import 'package:equatable/equatable.dart';

import '../data/models/quality_report.dart';

enum CapturePhase { menu, camera, gating, review }

class CaptureState extends Equatable {
  const CaptureState({this.phase = CapturePhase.menu, this.attempt = 1, this.report, this.source});
  final CapturePhase phase;

  /// 1 for the first photo; goes up on every retake and is sent with the upload.
  final int attempt;
  final QualityReport? report;
  final String? source;

  CaptureState copyWith({CapturePhase? phase, int? attempt, QualityReport? report, bool clearReport = false, String? source}) => CaptureState(
        phase: phase ?? this.phase,
        attempt: attempt ?? this.attempt,
        report: clearReport ? null : (report ?? this.report),
        source: source ?? this.source,
      );

  @override
  List<Object?> get props => [phase, attempt, report, source];
}
