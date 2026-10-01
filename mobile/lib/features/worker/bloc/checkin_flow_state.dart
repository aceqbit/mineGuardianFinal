import 'package:equatable/equatable.dart';

enum TickerStage { checking, uploading, synced, aiAnalyzing, done }

enum FailAction { retakePhoto, takeNewPhoto, retry }

enum FlowPhase { running, done, failed, queuedOffline }

class FlowFailure extends Equatable {
  const FlowFailure({required this.stage, required this.message, required this.action});
  final TickerStage stage;
  final String message;
  final FailAction action;
  @override
  List<Object?> get props => [stage, message, action];
}

class CheckinFlowState extends Equatable {
  const CheckinFlowState({
    this.phase = FlowPhase.running,
    this.stage = TickerStage.checking,
    this.progress = 0,
    this.detail = '',
    this.failure,
    this.aiSlow = false,
    this.checkInId,
    this.syncedAt,
    this.verdictLabel,
  });

  final FlowPhase phase;
  final TickerStage stage;
  final double progress;
  final String detail;
  final FlowFailure? failure;
  final bool aiSlow;
  final String? checkInId;
  final DateTime? syncedAt;
  final String? verdictLabel;

  CheckinFlowState copyWith({FlowPhase? phase, TickerStage? stage, double? progress, String? detail, FlowFailure? failure, bool clearFailure = false, bool? aiSlow, String? checkInId, DateTime? syncedAt, String? verdictLabel}) => CheckinFlowState(
        phase: phase ?? this.phase,
        stage: stage ?? this.stage,
        progress: progress ?? this.progress,
        detail: detail ?? this.detail,
        failure: clearFailure ? null : (failure ?? this.failure),
        aiSlow: aiSlow ?? this.aiSlow,
        checkInId: checkInId ?? this.checkInId,
        syncedAt: syncedAt ?? this.syncedAt,
        verdictLabel: verdictLabel ?? this.verdictLabel,
      );

  @override
  List<Object?> get props => [phase, stage, progress, detail, failure, aiSlow, checkInId, syncedAt, verdictLabel];
}
