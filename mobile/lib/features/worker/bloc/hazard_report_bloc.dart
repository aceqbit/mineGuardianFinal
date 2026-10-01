import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/db/layout_repository.dart';
import '../../../core/location/location_service.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/sync/outbox_queue.dart';
import '../../../core/sync/sync_engine.dart';
import '../data/hazard_repository.dart';
import '../data/models/quality_report.dart';
import '../data/quality_config.dart';
import '../data/quality_gate.dart';
import 'checkin_flow_state.dart';
import 'hazard_report_event.dart';
import 'hazard_report_state.dart';

/// Report Safety Hazard: photo + category + GPS. Offline-safe through the outbox.
class HazardReportBloc extends Bloc<HazardReportEvent, HazardReportState> {
  HazardReportBloc({
    required HazardRepository repo,
    required LocationService location,
    required SocketService socket,
    required LayoutRepository layout,
    required OutboxQueue queue,
    required SyncEngine engine,
    QualityGate? gate,
  })  : _repo = repo,
        _location = location,
        _socket = socket,
        _layout = layout,
        _queue = queue,
        _engine = engine,
        _gate = gate ?? QualityGate(),
        super(const HazardReportState()) {
    on<HazardStarted>((e, emit) => _refreshLocation(emit));
    on<HazardLocationRefreshed>((e, emit) => _refreshLocation(emit));
    on<HazardPhotoSelected>(_onPhoto);
    on<HazardPhotoCleared>((e, emit) => emit(state.copyWith(clearReport: true)));
    on<HazardCategorySelected>((e, emit) => emit(state.copyWith(category: e.category)));
    on<HazardSubmitted>(_onSubmit);
    on<HazardRetry>(_onSubmit);
    on<HazardFlowProgress>((e, emit) {
      final f = state.flow;
      if (f != null && f.stage == TickerStage.uploading) emit(state.copyWith(flow: f.copyWith(progress: e.value, detail: 'Uploading ${(e.value * 100).round()}%')));
    });
    on<HazardAiSlow>((e, emit) {
      final f = state.flow;
      if (f != null && f.stage == TickerStage.aiAnalyzing && f.phase == FlowPhase.running) emit(state.copyWith(flow: f.copyWith(aiSlow: true)));
    });
    on<HazardAiResult>(_onAi);
    on<HazardQueuedSynced>((e, emit) {
      emit(state.copyWith(flow: (state.flow ?? const CheckinFlowState()).copyWith(phase: FlowPhase.running, stage: TickerStage.synced, detail: 'Server check passed')));
      _awaitAi(e.hazardId);
    });
  }

  final HazardRepository _repo;
  final LocationService _location;
  final SocketService _socket;
  final LayoutRepository _layout;
  final OutboxQueue _queue;
  final SyncEngine _engine;
  final QualityGate _gate;
  final _subs = <StreamSubscription<dynamic>>[];
  StreamSubscription<dynamic>? _resultSub;
  Timer? _slow;
  String? _clientId;

  Future<void> _refreshLocation(Emitter<HazardReportState> emit) async {
    emit(state.copyWith(locationStatus: LocationStatus.loading));
    final fix = await _location.getCurrent();
    if (fix == null) {
      emit(state.copyWith(locationStatus: LocationStatus.unavailable, clearFix: true, clearZone: true));
      return;
    }
    final layout = await _layout.cached();
    emit(state.copyWith(locationStatus: LocationStatus.ready, fix: fix, zoneCode: layout?.zoneCodeAt(fix.lat, fix.lng), clearZone: layout?.zoneCodeAt(fix.lat, fix.lng) == null));
  }

  Future<void> _onPhoto(HazardPhotoSelected e, Emitter<HazardReportState> emit) async {
    emit(state.copyWith(gating: true, clearReport: true));
    QualityReport report;
    try {
      report = await _gate.evaluate(bytes: e.bytes, source: e.source, mode: GateMode.hazard, shutterAt: e.shutterAt);
    } catch (_) {
      report = QualityReport(failures: const [QualityFailure('UNREADABLE', 'This photo could not be checked — try another')], warnings: const [], metrics: const QualityMetrics(), capturedAt: e.shutterAt, exifTakenAt: null, source: e.source, sha256: '', uploadBytes: e.bytes, gateMs: 0);
    }
    emit(state.copyWith(gating: false, report: report));
  }

  Future<void> _onSubmit(HazardReportEvent e, Emitter<HazardReportState> emit) async {
    final r = state.report;
    final cat = state.category;
    if (r == null || cat == null || !r.pass) return;
    _clientId ??= HazardRepository.newClientId();
    final id = _clientId!;
    emit(state.copyWith(submitting: true, flow: CheckinFlowState(detail: 'Sharpness ${r.metrics.blurScore.round()} ✓ · Lighting ✓')));
    await Future<void>.delayed(const Duration(milliseconds: 400));
    emit(state.copyWith(flow: state.flow!.copyWith(stage: TickerStage.uploading, detail: 'Uploading 0%')));
    final fix = state.fix;
    try {
      final res = await _repo.upload(report: r, category: cat, clientId: id, fix: fix, onProgress: (p) => add(HazardFlowProgress(p)));
      emit(state.copyWith(flow: state.flow!.copyWith(stage: TickerStage.synced, checkInId: res.hazardId, detail: 'Server check passed')));
      _awaitAi(res.hazardId);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final f = state.flow;
      if (f != null && f.phase == FlowPhase.running && f.stage == TickerStage.synced) {
        emit(state.copyWith(flow: f.copyWith(stage: TickerStage.aiAnalyzing, detail: 'AI is classifying the severity…')));
      }
    } on ApiException catch (ex) {
      if (ex.isNetwork) {
        await _queue.enqueueHazard(clientId: id, photo: r.uploadBytes, payload: {
          'category': cat.wire,
          'capturedAt': r.capturedAt?.toUtc().toIso8601String(),
          'sha256': r.sha256,
          'source': r.source,
          if (fix != null) 'lat': fix.lat,
          if (fix != null) 'lng': fix.lng,
          if (fix != null) 'accuracyM': fix.accuracyM,
        });
        emit(state.copyWith(flow: state.flow!.copyWith(phase: FlowPhase.queuedOffline, stage: TickerStage.uploading, detail: 'Saved offline — it will send automatically when you are connected')));
        await _resultSub?.cancel();
        _resultSub = _engine.itemResult$.where((x) => x.id == id).listen((x) {
          if (x.success) {
            final h = (x.response?['hazard'] as Map?)?.cast<String, dynamic>();
            add(HazardQueuedSynced((h?['id'] ?? h?['_id'] ?? '').toString()));
          }
        });
        return;
      }
      final action = ex.code == 'QUALITY_REJECTED' ? FailAction.retakePhoto : FailAction.retry;
      emit(state.copyWith(flow: state.flow!.copyWith(phase: FlowPhase.failed, failure: FlowFailure(stage: TickerStage.uploading, message: ex.message, action: action))));
    } catch (_) {
      emit(state.copyWith(flow: state.flow!.copyWith(phase: FlowPhase.failed, failure: const FlowFailure(stage: TickerStage.uploading, message: 'Upload failed', action: FailAction.retry))));
    }
  }

  void _awaitAi(String hazardId) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _subs.add(_socket.on(SocketEvents.hazardClassified).listen((env) {
      if ((env.data['hazardId'] ?? '').toString() == hazardId) add(const HazardAiResult());
    }));
    _slow?.cancel();
    _slow = Timer(const Duration(seconds: 45), () {
      if (!isClosed) add(const HazardAiSlow());
    });
  }

  void _onAi(HazardAiResult e, Emitter<HazardReportState> emit) {
    for (final s in _subs) {
      s.cancel();
    }
    _slow?.cancel();
    emit(state.copyWith(flow: (state.flow ?? const CheckinFlowState()).copyWith(phase: FlowPhase.done, stage: TickerStage.done, detail: 'Hazard reported — your supervisor was alerted')));
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _resultSub?.cancel();
    _slow?.cancel();
    await _gate.dispose();
    return super.close();
  }
}
