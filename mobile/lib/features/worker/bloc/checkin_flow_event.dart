import 'package:equatable/equatable.dart';

import '../data/models/quality_report.dart';

sealed class CheckinFlowEvent extends Equatable {
  const CheckinFlowEvent();
  @override
  List<Object?> get props => [];
}

class CheckinFlowStarted extends CheckinFlowEvent {
  const CheckinFlowStarted({required this.report, required this.attempt});
  final QualityReport report;
  final int attempt;
}

class CheckinFlowRetry extends CheckinFlowEvent {
  const CheckinFlowRetry();
}

class CheckinFlowProgress extends CheckinFlowEvent {
  const CheckinFlowProgress(this.value);
  final double value;
  @override
  List<Object?> get props => [value];
}

class CheckinFlowAiSlow extends CheckinFlowEvent {
  const CheckinFlowAiSlow();
}

/// compliance:predicted or checkin:status arrived for this check-in.
class CheckinFlowAiResult extends CheckinFlowEvent {
  const CheckinFlowAiResult({required this.verdict, this.failedAi = false});
  final String? verdict;
  final bool failedAi;
  @override
  List<Object?> get props => [verdict, failedAi];
}

/// The outbox finished sending this check-in in the background (P1.7).
class CheckinFlowQueuedSynced extends CheckinFlowEvent {
  const CheckinFlowQueuedSynced(this.checkInId);
  final String checkInId;
  @override
  List<Object?> get props => [checkInId];
}
