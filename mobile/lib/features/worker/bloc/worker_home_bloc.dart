import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/enums.dart';
import '../../../contracts/socket_events.dart';
import '../../../core/socket/socket_service.dart';
import '../data/models/checkin_summary.dart';
import '../data/worker_repository.dart';
import 'worker_home_event.dart';
import 'worker_home_state.dart';

class WorkerHomeBloc extends Bloc<WorkerHomeEvent, WorkerHomeState> {
  WorkerHomeBloc({required WorkerRepository repo, required SocketService socket, required String userId})
      : _repo = repo,
        _socket = socket,
        _userId = userId,
        super(const WorkerHomeState()) {
    on<WorkerHomeStarted>(_load);
    on<WorkerHomeRefreshed>(_load);
    on<WorkerHomeSocketEvent>(_onSocket);
    on<WorkerHomeFlashCleared>((e, emit) => emit(state.copyWith(flashIds: {...state.flashIds}..remove(e.id), statsFlash: e.id == 'stats' ? false : state.statsFlash)));

    for (final ev in [SocketEvents.compliancePredicted, SocketEvents.complianceReviewed, SocketEvents.checkinStatus, SocketEvents.scoreUpdated]) {
      _subs.add(_socket.on(ev).listen((env) => add(WorkerHomeSocketEvent(ev, env.data))));
    }
  }

  final WorkerRepository _repo;
  final SocketService _socket;
  final String _userId;
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> _load(WorkerHomeEvent e, Emitter<WorkerHomeState> emit) async {
    if (e is WorkerHomeStarted) emit(state.copyWith(status: WorkerHomeStatus.loading));
    try {
      final results = await Future.wait([_repo.stats(), _repo.recent()]);
      emit(state.copyWith(status: WorkerHomeStatus.ready, stats: results[0] as WorkerStats?, clearStats: results[0] == null, checkins: results[1] as List<CheckinSummary>));
    } catch (_) {
      emit(state.copyWith(status: state.checkins.isEmpty ? WorkerHomeStatus.failure : WorkerHomeStatus.ready));
    }
  }

  Future<void> _onSocket(WorkerHomeSocketEvent e, Emitter<WorkerHomeState> emit) async {
    final d = e.data;
    if (e.event == SocketEvents.scoreUpdated) {
      if (d['workerId'] != null && d['workerId'].toString() != _userId) return;
      emit(state.copyWith(stats: WorkerStats.fromJson(d), statsFlash: true));
      _flashLater('stats');
      return;
    }
    if (d['workerId'] != null && d['workerId'].toString() != _userId) return;
    final id = (d['checkInId'] ?? '').toString();
    if (id.isEmpty) return;
    final idx = state.checkins.indexWhere((c) => c.id == id);
    if (idx < 0) {
      await _load(const WorkerHomeRefreshed(), emit);
      emit(state.copyWith(flashIds: {...state.flashIds, id}));
      _flashLater(id);
      return;
    }
    var item = state.checkins[idx];
    switch (e.event) {
      case SocketEvents.checkinStatus:
        item = item.copyWith(status: CheckinStatus.fromWire(d['status'] as String? ?? item.status.wire));
      case SocketEvents.compliancePredicted:
        item = item.copyWith(status: CheckinStatus.predicted, verdict: d['verdict'] is String ? Verdict.fromWire(d['verdict'] as String) : null);
      case SocketEvents.complianceReviewed:
        item = item.copyWith(
          status: CheckinStatus.reviewed,
          finalVerdict: d['finalVerdict'] is String ? Verdict.fromWire(d['finalVerdict'] as String) : null,
          decisionAction: d['action'] is String ? DecisionAction.fromWire(d['action'] as String) : null,
          missing: ((d['missing'] as List?) ?? const []).map((x) => PpeKey.fromWire(x as String)).toList(),
        );
    }
    final list = [...state.checkins]..[idx] = item;
    emit(state.copyWith(checkins: list, flashIds: {...state.flashIds, id}));
    _flashLater(id);
  }

  void _flashLater(String id) => Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (!isClosed) add(WorkerHomeFlashCleared(id));
      });

  @override
  Future<void> close() async {
    for (final s in _subs) {
      await s.cancel();
    }
    return super.close();
  }
}
