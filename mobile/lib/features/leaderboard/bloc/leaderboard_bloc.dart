import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../data/leaderboard_repository.dart';

class LeaderboardState extends Equatable {
  const LeaderboardState({this.loading = true, this.workers = const [], this.supervisors = const [], this.me, this.error});
  final bool loading;
  final List<LeaderRow> workers, supervisors;
  final MyStanding? me;
  final String? error;

  LeaderboardState copyWith({bool? loading, List<LeaderRow>? workers, List<LeaderRow>? supervisors, MyStanding? me, String? error, bool clearError = false}) =>
      LeaderboardState(loading: loading ?? this.loading, workers: workers ?? this.workers, supervisors: supervisors ?? this.supervisors, me: me ?? this.me, error: clearError ? null : (error ?? this.error));

  @override
  List<Object?> get props => [loading, workers, supervisors, me, error];
}

sealed class LeaderboardEvent {
  const LeaderboardEvent();
}

class LeaderboardStarted extends LeaderboardEvent {
  const LeaderboardStarted();
}

class _RefreshMe extends LeaderboardEvent {
  const _RefreshMe();
}

class _Live extends LeaderboardEvent {
  const _Live(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
}

/// Miners see their own standing; supervisors and admins also get the supervisor board. Live via leaderboard:updated and score:updated.
class LeaderboardBloc extends Bloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc({required LeaderboardRepository repo, required SocketService socket, required bool isMiner, required bool isStaff})
      : _repo = repo,
        _isMiner = isMiner,
        _isStaff = isStaff,
        super(const LeaderboardState()) {
    on<LeaderboardStarted>(_load);
    on<_Live>((e, emit) {
      if (e.event == SocketEvents.leaderboardUpdated) {
        final top = (e.data['top'] as List?)?.map((r) => LeaderRow.fromJson((r as Map).cast<String, dynamic>())).toList();
        if (top != null) emit(state.copyWith(workers: top));
        if (_isMiner) add(const _RefreshMe());
      } else if (_isMiner) {
        add(const _RefreshMe());
      }
    });
    on<_RefreshMe>((e, emit) async {
      try {
        emit(state.copyWith(me: await _repo.me()));
      } on ApiException {
        // keep the last known standing
      }
    });
    _subs.add(socket.on(SocketEvents.leaderboardUpdated).listen((env) => add(_Live(SocketEvents.leaderboardUpdated, env.data))));
    _subs.add(socket.on(SocketEvents.scoreUpdated).listen((env) => add(_Live(SocketEvents.scoreUpdated, env.data))));
  }

  final LeaderboardRepository _repo;
  final bool _isMiner, _isStaff;
  final _subs = <StreamSubscription<dynamic>>[];

  Future<void> _load(LeaderboardStarted e, Emitter<LeaderboardState> emit) async {
    try {
      final results = await Future.wait([
        _repo.workers(),
        _isStaff ? _repo.supervisors() : Future.value(const <LeaderRow>[]),
        _isMiner ? _repo.me() : Future.value(null),
      ]);
      emit(LeaderboardState(loading: false, workers: results[0] as List<LeaderRow>, supervisors: results[1] as List<LeaderRow>, me: results[2] as MyStanding?));
    } on ApiException catch (ex) {
      emit(state.copyWith(loading: false, error: ex.message));
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
