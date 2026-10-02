import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../data/broadcast_repository.dart';

class BroadcastInboxState extends Equatable {
  const BroadcastInboxState({this.sticky = const [], this.toast, this.seen = const {}});

  /// URGENT / EMERGENCY messages waiting for "Got it", newest first.
  final List<BroadcastMsg> sticky;

  /// The latest INFO message, shown briefly.
  final BroadcastMsg? toast;
  final Set<String> seen;

  @override
  List<Object?> get props => [sticky, toast, seen];
}

sealed class BroadcastInboxEvent extends Equatable {
  const BroadcastInboxEvent();
  @override
  List<Object?> get props => [];
}

class InboxStarted extends BroadcastInboxEvent {
  const InboxStarted();
}

class InboxReceived extends BroadcastInboxEvent {
  const InboxReceived(this.msg);
  final BroadcastMsg msg;
  @override
  List<Object?> get props => [msg];
}

class InboxGotIt extends BroadcastInboxEvent {
  const InboxGotIt(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class InboxToastDismissed extends BroadcastInboxEvent {
  const InboxToastDismissed();
}

/// Everyone's incoming broadcasts. Acks DELIVERED on arrival and READ on "Got it"; catches up after a reconnect.
class BroadcastInboxBloc extends Bloc<BroadcastInboxEvent, BroadcastInboxState> {
  BroadcastInboxBloc({required BroadcastRepository repo, required SocketService socket}) : _repo = repo, _socket = socket, super(const BroadcastInboxState()) {
    on<InboxStarted>(_start);
    on<InboxReceived>(_received);
    on<InboxGotIt>((e, emit) {
      unawaited(_ack(e.id, 'READ'));
      emit(BroadcastInboxState(sticky: [for (final m in state.sticky) if (m.id != e.id) m], toast: state.toast, seen: state.seen));
    });
    on<InboxToastDismissed>((e, emit) => emit(BroadcastInboxState(sticky: state.sticky, seen: state.seen)));
    _subs.add(socket.on(SocketEvents.broadcastMessage).listen((env) => add(InboxReceived(BroadcastMsg.fromJson(env.data)))));
    _subs.add(socket.connection$.where((c) => c).skip(1).listen((_) => add(const InboxStarted())));
  }

  final BroadcastRepository _repo;
  final SocketService _socket;
  final _subs = <StreamSubscription<dynamic>>[];
  DateTime? _lastSeen;

  Future<void> _ack(String id, String status) async {
    try {
      await _socket.emit(SocketEvents.broadcastAck, {'broadcastId': id, 'status': status});
    } catch (_) {
      // the server only needs the counters; a missed ack is harmless
    }
  }

  Future<void> _start(InboxStarted e, Emitter<BroadcastInboxState> emit) async {
    try {
      final missed = await _repo.catchUp(_lastSeen);
      for (final m in missed) {
        add(InboxReceived(m));
      }
    } on ApiException {
      // offline: the socket will deliver new ones
    }
  }

  void _received(InboxReceived e, Emitter<BroadcastInboxState> emit) {
    final m = e.msg;
    if (state.seen.contains(m.id)) return;
    if (m.createdAt != null && (_lastSeen == null || m.createdAt!.isAfter(_lastSeen!))) _lastSeen = m.createdAt;
    unawaited(_ack(m.id, 'DELIVERED'));
    final seen = {...state.seen, m.id};
    if (m.sticky) {
      emit(BroadcastInboxState(sticky: [m, ...state.sticky], toast: state.toast, seen: seen));
    } else {
      emit(BroadcastInboxState(sticky: state.sticky, toast: m, seen: seen));
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
