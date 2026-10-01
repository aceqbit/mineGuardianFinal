import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../../../core/time/ist.dart';
import '../data/models/checkin_summary.dart';

enum WorkerHomeStatus { loading, ready, failure }

class WorkerHomeState extends Equatable {
  const WorkerHomeState({this.status = WorkerHomeStatus.loading, this.stats, this.checkins = const [], this.flashIds = const {}, this.statsFlash = false});
  final WorkerHomeStatus status;
  final WorkerStats? stats;
  final List<CheckinSummary> checkins;
  final Set<String> flashIds;
  final bool statsFlash;

  WorkerHomeState copyWith({WorkerHomeStatus? status, WorkerStats? stats, bool clearStats = false, List<CheckinSummary>? checkins, Set<String>? flashIds, bool? statsFlash}) => WorkerHomeState(
        status: status ?? this.status,
        stats: clearStats ? null : (stats ?? this.stats),
        checkins: checkins ?? this.checkins,
        flashIds: flashIds ?? this.flashIds,
        statsFlash: statsFlash ?? this.statsFlash,
      );

  /// Latest check-in captured today (IST), if any.
  CheckinSummary? get todays {
    final now = DateTime.now();
    for (final c in checkins) {
      if (sameIstDay(c.capturedAt, now)) return c;
    }
    return null;
  }

  /// Subtitle for the "Capture Shift Photo" tile.
  String get captureSubtitle {
    final c = todays;
    if (c == null) return 'Not submitted today';
    switch (c.status) {
      case CheckinStatus.received:
      case CheckinStatus.analyzing:
        return 'AI checking…';
      case CheckinStatus.predicted:
      case CheckinStatus.failedAi:
        return 'Awaiting supervisor';
      case CheckinStatus.reviewed:
        return c.finalVerdict == Verdict.compliant ? 'Verified ✓' : 'Retake needed';
      case CheckinStatus.rejectedQuality:
        return 'Retake needed';
    }
  }

  @override
  List<Object?> get props => [status, stats, checkins, flashIds, statsFlash];
}
