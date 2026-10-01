import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/enums.dart';
import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_item.dart';
import 'supervisor_feed_event.dart';
import 'supervisor_feed_state.dart';

/// Snapshot over REST, then live deltas over Socket.io merged by entity id; a full reload after any reconnect.
class SupervisorFeedBloc extends Bloc<SupervisorFeedEvent, SupervisorFeedState> {
  SupervisorFeedBloc({required FeedRepository repo, required SocketService socket}) : _repo = repo, _socket = socket, super(const SupervisorFeedState()) {
    on<FeedStarted>(_onStart);
    on<FeedRefreshed>((e, emit) => _load(emit, state.zoneId));
    on<FeedFilterChanged>((e, emit) => emit(state.copyWith(filter: e.filter)));
    on<FeedSocketEvent>(_onSocket);
    on<FeedReconnected>((e, emit) => _load(emit, state.zoneId, silent: true));
    on<HazardActionRequested>(_onHazardAction);
    on<FeedErrorShown>((e, emit) => emit(state.copyWith(clearError: true)));

    for (final ev in [
      SocketEvents.checkinNew, SocketEvents.compliancePredicted, SocketEvents.complianceReviewed,
      SocketEvents.hazardNew, SocketEvents.hazardClassified, SocketEvents.hazardUpdated,
      SocketEvents.sosTriggered, SocketEvents.sosCancelled,
    ]) {
      _subs.add(_socket.on(ev).listen((env) => add(FeedSocketEvent(ev, env.data))));
    }
    // reload the snapshot after every reconnect to fill gaps
    var wasUp = _socket.isConnected;
    _subs.add(_socket.connection$.listen((up) {
      if (up && !wasUp) add(const FeedReconnected());
      wasUp = up;
    }));
  }

  final FeedRepository _repo;
  final SocketService _socket;
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> _onStart(FeedStarted e, Emitter<SupervisorFeedState> emit) async {
    emit(state.copyWith(status: FeedStatus.loading, zoneId: e.zoneId));
    await _load(emit, e.zoneId);
  }

  Future<void> _load(Emitter<SupervisorFeedState> emit, String? zoneId, {bool silent = false}) async {
    try {
      final snap = await _repo.snapshot(zoneId: zoneId);
      final bands = await _repo.riskBands(snap.zoneId);
      emit(state.copyWith(
        status: FeedStatus.ready,
        zoneId: snap.zoneId,
        zoneCode: snap.zoneCode,
        zoneName: snap.zoneName,
        workers: [for (final w in snap.workers) w.copyWith(riskBand: bands[w.id])],
        checkins: snap.checkins,
        hazards: snap.hazards,
        sos: snap.sos,
        clearError: true,
      ));
    } on ApiException catch (ex) {
      if (!silent || state.status == FeedStatus.loading) emit(state.copyWith(status: state.status == FeedStatus.ready ? FeedStatus.ready : FeedStatus.failure, error: ex.message));
    }
  }

  bool _inZone(Map<String, dynamic> d) {
    final z = d['zoneId']?.toString();
    return z == null || state.zoneId == null || z == state.zoneId;
  }

  void _onSocket(FeedSocketEvent e, Emitter<SupervisorFeedState> emit) {
    final d = e.data;
    if (!_inZone(d)) return;
    switch (e.event) {
      case SocketEvents.checkinNew:
        final item = CheckinFeed.fromJson(d);
        if (state.checkins.any((c) => c.id == item.id)) return;
        emit(state.copyWith(
          checkins: [item, ...state.checkins],
          workers: [for (final w in state.workers) w.id == item.workerId ? w.copyWith(status: 'RECEIVED') : w],
        ));
      case SocketEvents.compliancePredicted:
        final id = d['checkInId'].toString();
        final crit = (d['criticality'] as Map?)?.cast<String, dynamic>();
        final em = (d['emergency'] as Map?)?.cast<String, dynamic>();
        final rv = ReviewSummary(
          reviewId: d['reviewId']?.toString(),
          verdict: d['verdict'] is String ? Verdict.fromWire(d['verdict'] as String) : null,
          confidence: (d['overallConfidence'] as num?)?.toDouble(),
          critLevel: crit?['level'] is String ? Criticality.fromWire(crit!['level'] as String) : null,
          critScore: (crit?['score'] as num?)?.round(),
          summary: d['summary'] as String?,
          emergencyDetected: em?['detected'] == true,
          emergencyPossible: em?['possible'] == true,
        );
        emit(state.copyWith(
          checkins: _replaceCheckin(id, (c) => c.copyWith(status: CheckinStatus.predicted, review: rv)),
          workers: [for (final w in state.workers) w.id == d['workerId']?.toString() ? w.copyWith(status: 'PREDICTED') : w],
        ));
      case SocketEvents.complianceReviewed:
        final id = d['checkInId'].toString();
        emit(state.copyWith(
          checkins: _replaceCheckin(id, (c) => c.copyWith(
                status: CheckinStatus.reviewed,
                review: (c.review ?? const ReviewSummary()).copyWith(
                  action: d['action'] is String ? DecisionAction.fromWire(d['action'] as String) : null,
                  finalVerdict: d['finalVerdict'] is String ? Verdict.fromWire(d['finalVerdict'] as String) : null,
                ),
              )),
          workers: [for (final w in state.workers) w.id == d['workerId']?.toString() ? w.copyWith(status: 'REVIEWED') : w],
        ));
      case SocketEvents.hazardNew:
        final h = HazardFeed.fromJson(d);
        if (state.hazards.any((x) => x.id == h.id)) return;
        emit(state.copyWith(hazards: [h, ...state.hazards], alertSeq: state.alertSeq + 1));
      case SocketEvents.hazardClassified:
        final id = d['hazardId'].toString();
        final sev = d['severity'];
        emit(state.copyWith(hazards: [
          for (final h in state.hazards)
            h.id == id
                ? h.copyWith(
                    severity: sev is String ? HazardSeverity.fromWire(sev) : null,
                    aiSummary: d['summary'] as String?,
                    emergencyDetected: (d['emergency'] as Map?)?['detected'] == true,
                  )
                : h,
        ]));
      case SocketEvents.hazardUpdated:
        final id = d['hazardId'].toString();
        final st = HazardStatus.fromWire(d['status'] as String);
        final now = DateTime.now().toUtc();
        emit(state.copyWith(hazards: [
          for (final h in state.hazards)
            h.id == id ? h.copyWith(status: st, acknowledgedAt: st == HazardStatus.acknowledged ? now : null, closedAt: st == HazardStatus.closed || st == HazardStatus.rejected ? now : null) : h,
        ]));
      case SocketEvents.sosTriggered:
        final s = SosFeed.fromJson(d);
        if (state.sos.any((x) => x.id == s.id)) return;
        emit(state.copyWith(sos: [s, ...state.sos], alertSeq: state.alertSeq + 1));
      case SocketEvents.sosCancelled:
        final id = d['sosId'].toString();
        emit(state.copyWith(sos: state.sos.where((s) => s.id != id).toList()));
    }
  }

  List<CheckinFeed> _replaceCheckin(String id, CheckinFeed Function(CheckinFeed) f) => [for (final c in state.checkins) c.id == id ? f(c) : c];

  /// Optimistic update with rollback on error.
  Future<void> _onHazardAction(HazardActionRequested e, Emitter<SupervisorFeedState> emit) async {
    final before = state.hazards;
    final now = DateTime.now().toUtc();
    emit(state.copyWith(hazards: [
      for (final h in before)
        h.id == e.hazardId
            ? h.copyWith(status: e.status, acknowledgedAt: e.status == HazardStatus.acknowledged ? now : null, closedAt: e.status != HazardStatus.acknowledged ? now : null, closeNote: e.note)
            : h,
    ]));
    try {
      final saved = await _repo.updateHazard(e.hazardId, e.status, note: e.note);
      emit(state.copyWith(hazards: [for (final h in state.hazards) h.id == e.hazardId ? h.copyWith(status: saved.status) : h]));
    } on ApiException catch (ex) {
      emit(state.copyWith(hazards: before, error: ex.message));
    }
  }

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
