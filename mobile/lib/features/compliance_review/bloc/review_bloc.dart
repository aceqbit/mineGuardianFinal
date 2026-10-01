import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/enums.dart';
import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../data/models/review_models.dart';
import '../data/review_repository.dart';
import 'review_event.dart';
import 'review_state.dart';

/// The supervisor decides EVERY required checklist item after seeing the AI output, then Confirm / Override / Escalate.
class ReviewBloc extends Bloc<ReviewEvent, ReviewState> {
  ReviewBloc({required ReviewRepository repo, required SocketService socket, required String checkInId}) : _repo = repo, _checkInId = checkInId, super(const ReviewState()) {
    on<ReviewLoaded>(_load);
    on<ItemSelected>((e, emit) {
      if (state.locked || state.submitting) return;
      emit(state.copyWith(selected: {...state.selected, e.key: e.status}));
    });
    on<DecisionSubmitted>(_submit);
    on<ReviewSocketEvent>(_onSocket);
    on<ReviewNoticeShown>((e, emit) => emit(state.copyWith(clearMessages: true)));
    _subs.add(socket.on(SocketEvents.complianceReviewed).listen((env) => add(ReviewSocketEvent(SocketEvents.complianceReviewed, env.data))));
    _subs.add(socket.on(SocketEvents.compliancePredicted).listen((env) => add(ReviewSocketEvent(SocketEvents.compliancePredicted, env.data))));
  }

  final ReviewRepository _repo;
  final String _checkInId;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _myName;
  set myName(String? v) => _myName = v;

  /// Rows start selected only when the AI said PRESENT or ABSENT at confidence >= 0.60. UNCERTAIN rows start unselected.
  Map<PpeKey, PpeStatus> _initialSelection(ReviewData d) {
    if (d.decision != null) return const {};
    return {for (final i in d.ai.requiredItems) if (i.preselectable) i.key: i.status};
  }

  Future<void> _load(ReviewLoaded e, Emitter<ReviewState> emit) async {
    try {
      final d = await _repo.byCheckIn(_checkInId);
      emit(state.copyWith(status: ReviewStatus.ready, data: d, selected: state.status == ReviewStatus.ready && state.selected.isNotEmpty ? state.selected : _initialSelection(d)));
    } on ApiException catch (ex) {
      emit(state.copyWith(status: ex.statusCode == 404 ? ReviewStatus.notFound : ReviewStatus.failure, error: ex.message));
    }
  }

  Future<void> _submit(DecisionSubmitted e, Emitter<ReviewState> emit) async {
    final d = state.data;
    if (d == null || state.submitting || !state.allDecided) return;
    emit(state.copyWith(submitting: true, clearMessages: true));
    try {
      await _repo.decide(d.reviewId, action: e.action, level: e.level, items: {for (final i in state.required) i.key: state.selected[i.key]!}, note: e.note);
      emit(state.copyWith(submitting: false, done: true, message: switch (e.action) { DecisionAction.confirm => 'Confirmed', DecisionAction.overrideAction => 'Override saved', DecisionAction.escalate => e.level == EscalationLevel.emergency ? 'Escalated — crisis mode requested' : 'Escalated to admin' }));
    } on ApiException catch (ex) {
      emit(state.copyWith(submitting: false, error: ex.message));
      if (ex.code == 'ALREADY_DECIDED') add(const ReviewLoaded());
    }
  }

  void _onSocket(ReviewSocketEvent e, Emitter<ReviewState> emit) {
    final d = e.data;
    if ((d['checkInId'] ?? '').toString() != _checkInId) return;
    if (e.event == SocketEvents.complianceReviewed) {
      if (state.done) return; // our own decision echoing back
      final who = d['decidedBy']?.toString() ?? 'a supervisor';
      if (_myName != null && who == _myName) return;
      final action = d['action'] as String? ?? '';
      emit(state.copyWith(lockedBy: 'Already reviewed by $who · ${action.isEmpty ? '' : DecisionAction.fromWire(action).name}'.trim()));
    } else {
      add(const ReviewLoaded()); // a re-run refreshed the AI result
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
