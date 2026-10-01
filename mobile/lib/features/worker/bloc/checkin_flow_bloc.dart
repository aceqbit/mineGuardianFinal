import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../data/checkin_repository.dart';
import '../data/models/quality_report.dart';
import 'checkin_flow_event.dart';
import 'checkin_flow_state.dart';

/// Drives the StatusTicker: CHECKING -> UPLOADING -> SYNCED -> AI_ANALYZING -> DONE (or FAILED).
class CheckinFlowBloc extends Bloc<CheckinFlowEvent, CheckinFlowState> {
  CheckinFlowBloc({required CheckinRepository repo, required SocketService socket})
      : _repo = repo,
        _socket = socket,
        super(const CheckinFlowState()) {
    on<CheckinFlowStarted>(_onStart);
    on<CheckinFlowRetry>((e, emit) async {
      final r = _report;
      if (r != null) await _run(r, _attempt, emit);
    });
    on<CheckinFlowProgress>((e, emit) {
      if (state.stage == TickerStage.uploading) emit(state.copyWith(progress: e.value, detail: 'Uploading ${(e.value * 100).round()}%'));
    });
    on<CheckinFlowAiSlow>((e, emit) {
      if (state.stage == TickerStage.aiAnalyzing && state.phase == FlowPhase.running) emit(state.copyWith(aiSlow: true));
    });
    on<CheckinFlowAiResult>(_onAiResult);
    on<CheckinFlowQueuedSynced>((e, emit) {
      emit(state.copyWith(phase: FlowPhase.running, stage: TickerStage.synced, checkInId: e.checkInId, syncedAt: DateTime.now(), detail: 'Server check passed'));
      _awaitAi(e.checkInId);
    });
  }

  final CheckinRepository _repo;
  final SocketService _socket;
  QualityReport? _report;
  int _attempt = 1;
  String? _clientId;
  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _slowTimer;

  String get clientId => _clientId ??= CheckinRepository.newClientId();

  Future<void> _onStart(CheckinFlowStarted e, Emitter<CheckinFlowState> emit) async {
    _report = e.report;
    _attempt = e.attempt;
    _clientId = CheckinRepository.newClientId();
    await _run(e.report, e.attempt, emit);
  }

  String _gateDetail(QualityReport r) {
    final parts = <String>['Sharpness ${r.metrics.blurScore.round()} ✓', 'Lighting ✓'];
    if (r.metrics.poseChecked && r.metrics.poseOk) parts.add('Full body ✓');
    return parts.join(' · ');
  }

  Future<void> _run(QualityReport r, int attempt, Emitter<CheckinFlowState> emit) async {
    emit(CheckinFlowState(stage: TickerStage.checking, detail: _gateDetail(r)));
    await Future<void>.delayed(const Duration(milliseconds: 450));
    emit(state.copyWith(stage: TickerStage.uploading, progress: 0, detail: 'Uploading 0%'));
    try {
      final fix = await _repo.currentLocation();
      final res = await _repo.upload(
        report: r,
        attempt: attempt,
        clientId: clientId,
        fix: fix,
        onProgress: (p) => add(CheckinFlowProgress(p)),
      );
      final now = DateTime.now();
      emit(state.copyWith(stage: TickerStage.synced, checkInId: res.checkInId, syncedAt: now, detail: 'Server check passed'));
      _awaitAi(res.checkInId); // subscribe before any delay so a fast AI result is never missed
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (state.phase == FlowPhase.running && state.stage == TickerStage.synced) {
        emit(state.copyWith(stage: TickerStage.aiAnalyzing, detail: 'AI checking your PPE…'));
      }
    } on ApiException catch (ex) {
      emit(state.copyWith(phase: FlowPhase.failed, failure: _failureFor(ex)));
    } catch (_) {
      emit(state.copyWith(phase: FlowPhase.failed, failure: const FlowFailure(stage: TickerStage.uploading, message: 'Upload failed', action: FailAction.retry)));
    }
  }

  FlowFailure _failureFor(ApiException ex) {
    switch (ex.code) {
      case 'QUALITY_REJECTED':
        return const FlowFailure(stage: TickerStage.synced, message: 'The server rejected this photo — please retake it', action: FailAction.retakePhoto);
      case 'DUPLICATE_PHOTO':
        return const FlowFailure(stage: TickerStage.synced, message: 'This exact photo was already submitted', action: FailAction.takeNewPhoto);
      case 'HASH_MISMATCH':
        return const FlowFailure(stage: TickerStage.uploading, message: 'Upload was corrupted — try again', action: FailAction.retry);
      case 'NETWORK':
        return const FlowFailure(stage: TickerStage.uploading, message: 'No connection', action: FailAction.retry);
      default:
        return FlowFailure(stage: TickerStage.uploading, message: ex.message, action: FailAction.retry);
    }
  }

  void _awaitAi(String checkInId) {
    _cancelSubs();
    _subs.add(_socket.on(SocketEvents.compliancePredicted).listen((env) {
      if ((env.data['checkInId'] ?? '').toString() == checkInId) add(CheckinFlowAiResult(verdict: env.data['verdict'] as String?));
    }));
    _subs.add(_socket.on(SocketEvents.checkinStatus).listen((env) {
      if ((env.data['checkInId'] ?? '').toString() != checkInId) return;
      final s = env.data['status'] as String?;
      if (s == 'FAILED_AI') add(const CheckinFlowAiResult(verdict: null, failedAi: true));
    }));
    _slowTimer?.cancel();
    _slowTimer = Timer(const Duration(seconds: 45), () {
      if (!isClosed) add(const CheckinFlowAiSlow());
    });
  }

  void _onAiResult(CheckinFlowAiResult e, Emitter<CheckinFlowState> emit) {
    _cancelSubs();
    _slowTimer?.cancel();
    final label = e.failedAi ? 'AI could not assess this photo — your supervisor will review it' : 'AI done: awaiting supervisor';
    emit(state.copyWith(phase: FlowPhase.done, stage: TickerStage.done, detail: label, verdictLabel: e.verdict));
  }

  void _cancelSubs() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }

  @override
  Future<void> close() {
    _cancelSubs();
    _slowTimer?.cancel();
    return super.close();
  }
}
