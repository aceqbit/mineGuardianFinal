import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/global_overlays.dart';
import 'package:mine_guardian/app/siren.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/contracts/socket_events.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/models/session_user.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/admin_home/data/admin_repository.dart';
import 'package:mine_guardian/features/broadcast/bloc/broadcast_inbox_bloc.dart';
import 'package:mine_guardian/features/broadcast/data/broadcast_repository.dart';
import 'package:mine_guardian/features/broadcast/view/broadcast_screen.dart';
import 'package:mine_guardian/features/crisis/bloc/crisis_bloc.dart';
import 'package:mine_guardian/features/crisis/data/crisis_repository.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Repo implements BroadcastRepository {
  final sent = <String>[];
  List<BroadcastMsg> missed = const [];
  @override
  Future<void> send({required String text, required BroadcastPriority priority, required BroadcastScope scope, String? zoneId, String? role}) async => sent.add('$scope:$priority:$text');
  @override
  Future<List<BroadcastMsg>> catchUp(DateTime? since) async => missed;
  @override
  Future<List<BroadcastMsg>> history() async => [const BroadcastMsg(id: 'b1', text: 'Gas alert in Zone B', priority: BroadcastPriority.urgent, senderName: 'Anita', targets: 4, delivered: 1, read: 0)];
  @override
  Future<List<BroadcastReplyMsg>> replies() async => const [BroadcastReplyMsg(id: 'r1', userName: 'Ravi Kumar', text: 'Copy, moving out', broadcastId: 'b1')];
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _NoSiren implements SirenPlayer {
  @override
  Future<void> play() async {}
  @override
  Future<void> stop() async {}
}

class _NoCrisis implements CrisisRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

void main() {
  late SocketService socket;
  setUp(() => socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x'));

  group('BroadcastInboxBloc', () {
    test('URGENT and EMERGENCY stick until Got it; INFO is a toast; duplicates are ignored', () async {
      final bloc = BroadcastInboxBloc(repo: _Repo(), socket: socket);
      socket.inject(SocketEvents.broadcastMessage, {'id': 'u1', 'text': 'Evacuate zone B', 'priority': 'EMERGENCY', 'senderName': 'Anita', 'createdAt': DateTime.now().toUtc().toIso8601String()}, id: 'e1');
      socket.inject(SocketEvents.broadcastMessage, {'id': 'i1', 'text': 'Shift change at 2', 'priority': 'INFO', 'senderName': 'Anita', 'createdAt': DateTime.now().toUtc().toIso8601String()}, id: 'e2');
      socket.inject(SocketEvents.broadcastMessage, {'id': 'u1', 'text': 'Evacuate zone B', 'priority': 'EMERGENCY', 'senderName': 'Anita'}, id: 'e3');
      await settle();
      expect(bloc.state.sticky.length, 1);
      expect(bloc.state.toast?.id, 'i1');
      bloc.add(const InboxGotIt('u1'));
      await settle();
      expect(bloc.state.sticky, isEmpty);
      await bloc.close();
    });

    test('catch-up after start delivers missed messages once', () async {
      final repo = _Repo()..missed = [const BroadcastMsg(id: 'm1', text: 'Missed', priority: BroadcastPriority.urgent, senderName: 'A')];
      final bloc = BroadcastInboxBloc(repo: repo, socket: socket)..add(const InboxStarted());
      await settle();
      socket.inject(SocketEvents.broadcastMessage, {'id': 'm1', 'text': 'Missed', 'priority': 'URGENT', 'senderName': 'A'}, id: 'x');
      await settle();
      expect(bloc.state.sticky.length, 1);
      await bloc.close();
    });
  });

  testWidgets('a sticky banner shows over any screen and Got it removes it', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
    final session = SessionBloc(auth: _FakeAuth(), api: api)..add(const LoggedIn(SessionUser(id: 'u1', role: Role.miner, fullName: 'T', employeeId: 'T-1', phoneE164: '+919876500001')));
    final crisis = CrisisBloc(repo: _NoCrisis(), socket: socket, isStaff: () => false);
    final inbox = BroadcastInboxBloc(repo: _Repo(), socket: socket);
    await t.pumpWidget(MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
      child: BlocProvider<SessionBloc>.value(
        value: session,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: GlobalOverlays(crisisBloc: crisis, inboxBloc: inbox, siren: SirenController(player: _NoSiren()), child: const Scaffold(body: Text('home')))),
      ),
    ));
    await t.pump(const Duration(milliseconds: 100));
    socket.inject(SocketEvents.broadcastMessage, {'id': 'u9', 'text': 'Roof fall in Zone A', 'priority': 'URGENT', 'senderName': 'Anita'});
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Roof fall in Zone A'), findsOneWidget);
    await t.tap(find.text('Got it'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Roof fall in Zone A'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });

  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('broadcast composer at ${w.toInt()}px: live counters and replies', (t) async {
      t.view.physicalSize = Size(w, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final session = SessionBloc(auth: _FakeAuth(), api: api);
      await t.pumpWidget(MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
        child: BlocProvider<SessionBloc>.value(
          value: session,
          child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: BroadcastScreen(repository: _Repo(), zones: const <ZoneOverview>[])),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Gas alert in Zone B'), findsOneWidget);
      expect(find.text('Delivered 1/4 · Read 0 · Replies 0'), findsOneWidget);
      expect(find.text('Copy, moving out'), findsOneWidget);
      socket.inject(SocketEvents.broadcastStats, {'broadcastId': 'b1', 'targets': 4, 'delivered': 3, 'read': 2});
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Delivered 3/4 · Read 2 · Replies 0'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
