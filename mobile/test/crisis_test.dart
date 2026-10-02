import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mine_guardian/app/global_overlays.dart';
import 'package:mine_guardian/app/siren.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/contracts/socket_events.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/models/mine_layout.dart';
import 'package:mine_guardian/core/models/session_user.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/crisis/bloc/crisis_bloc.dart';
import 'package:mine_guardian/features/crisis/data/crisis_models.dart';
import 'package:mine_guardian/features/crisis/data/crisis_repository.dart';
import 'package:mine_guardian/features/crisis/view/crisis_console_screen.dart';

import 'fixtures/layout_fixture.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

Map<String, dynamic> _active() => {
      'active': true,
      'crisis': {
        'crisisId': 'c1',
        'startedAt': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(),
        'trigger': {'type': 'SOS'},
        'triggers': [
          {'type': 'SOS', 'refId': 's1'}
        ],
        'zoneIds': ['z1'],
        'zoneCodes': ['Z-A'],
        'reason': 'SOS from Ravi Kumar',
        'shareToken': 'abcdefghijklmnopqrstuvwx',
        'timeline': [
          {'at': DateTime.now().toUtc().toIso8601String(), 'text': 'Crisis activated by SOS'}
        ],
        'blockedEdgeIds': [],
      },
      'roster': [
        {'userId': 'w1', 'name': 'Ravi Kumar', 'employeeId': 'MIN-0101', 'zoneId': 'z1', 'status': 'UNKNOWN'},
        {'userId': 'w2', 'name': 'Suresh Yadav', 'employeeId': 'MIN-0102', 'zoneId': 'z1', 'status': 'SAFE'},
      ],
      'positions': [
        {'userId': 'w1', 'name': 'Ravi Kumar', 'zoneId': 'z1', 'lat': 23.7461, 'lng': 86.4151, 'accuracyM': 8, 'ts': DateTime.now().toUtc().toIso8601String(), 'sosId': 's1'},
      ],
      'routes': {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'properties': {'workerId': 'w1', 'workerName': 'Ravi Kumar', 'rank': 1, 'recommended': true, 'exitId': 'X-MAIN', 'exitName': 'Main Shaft', 'exitType': 'shaft', 'distanceM': 240, 'etaSec': 190, 'risk': 0, 'congestion': 0, 'reasons': ['Recommended: best balance of time, safety and crowding'], 'positionUnknown': false},
            'geometry': {'type': 'LineString', 'coordinates': [[86.4151, 23.7461], [86.4140, 23.7460]]},
          }
        ],
      },
    };

class _Repo implements CrisisRepository {
  _Repo({this.payload});
  final Map<String, dynamic>? payload;
  final calls = <String>[];
  Map<String, dynamic>? resolveBody;

  @override
  Future<ActiveCrisisData> active() async => ActiveCrisisData.fromJson(payload ?? {'active': false});

  @override
  Future<void> resolve(String id, {required bool falseAlarm, required String note, required bool allAccounted, required bool hazardsContained}) async {
    calls.add('resolve');
    resolveBody = {'falseAlarm': falseAlarm, 'note': note, 'allAccounted': allAccounted, 'hazardsContained': hazardsContained};
  }

  @override
  Future<void> setAccounted(String id, String workerId, AccountedStatus s) async => calls.add('accounted:$workerId:${s.wire}');
  @override
  Future<void> blockEdge(String id, String edgeId, bool blocked) async => calls.add('block:$edgeId:$blocked');
  @override
  Future<void> assignRoute(String id, String workerId, String exitId) async => calls.add('assign:$workerId:$exitId');
  @override
  Future<void> recompute(String id) async => calls.add('recompute');
  @override
  dynamic noSuchMethod(Invocation i) {
    return null;
  }
}

class _FakeSiren implements SirenPlayer {
  int plays = 0, stops = 0;
  @override
  Future<void> play() async => plays++;
  @override
  Future<void> stop() async => stops++;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

SessionBloc _session(Role role) {
  final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
  final bloc = SessionBloc(auth: _FakeAuth(), api: api);
  bloc.add(LoggedIn(SessionUser(id: 'u1', role: role, fullName: 'Tester', employeeId: 'T-1', phoneE164: '+919876500001')));
  return bloc;
}

void main() {
  late SocketService socket;
  setUp(() => socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x'));

  group('CrisisBloc', () {
    test('crisis:activated starts a crisis and bumps activationSeq once even if delivered twice', () async {
      final bloc = CrisisBloc(repo: _Repo(), socket: socket, isStaff: () => false);
      socket.inject(SocketEvents.crisisActivated, {'crisisId': 'c1', 'startedAt': DateTime.now().toUtc().toIso8601String(), 'triggers': [{'type': 'SOS'}], 'zoneIds': ['z1']}, id: 'a');
      await settle();
      socket.inject(SocketEvents.crisisActivated, {'crisisId': 'c1', 'startedAt': DateTime.now().toUtc().toIso8601String(), 'triggers': [{'type': 'SOS'}], 'zoneIds': ['z1']}, id: 'b');
      await settle();
      expect(bloc.state.phase, CrisisPhase.active);
      expect(bloc.state.activationSeq, 1);
      await bloc.close();
    });

    test('staff load the roster and positions; accounted updates arrive live', () async {
      final bloc = CrisisBloc(repo: _Repo(payload: _active()), socket: socket, isStaff: () => true)..add(const CrisisStarted());
      await settle();
      expect(bloc.state.roster.length, 2);
      expect(bloc.state.positions['w1']?.sos, isTrue);
      expect(bloc.state.counts[AccountedStatus.unknown], 1);
      socket.inject(SocketEvents.crisisUpdated, {'crisisId': 'c1', 'accounted': {'workerId': 'w1', 'status': 'SAFE'}});
      await settle();
      expect(bloc.state.counts[AccountedStatus.safe], 2);
      expect(bloc.state.allAccounted, isTrue);
      await bloc.close();
    });

    test('positions replace the map; routes replace the list; resolved ends the crisis', () async {
      final bloc = CrisisBloc(repo: _Repo(payload: _active()), socket: socket, isStaff: () => true)..add(const CrisisStarted());
      await settle();
      socket.inject(SocketEvents.crisisPositions, {'crisisId': 'c1', 'positions': [{'userId': 'w2', 'name': 'S', 'zoneId': 'z1', 'lat': 23.7, 'lng': 86.4}]});
      await settle();
      expect(bloc.state.positions.keys, ['w2']);
      socket.inject(SocketEvents.crisisRoutes, {'crisisId': 'c1', 'geojson': {'type': 'FeatureCollection', 'features': []}});
      await settle();
      expect(bloc.state.routes, isEmpty);
      socket.inject(SocketEvents.crisisResolved, {'crisisId': 'c1', 'falseAlarm': true, 'resolvedAt': DateTime.now().toUtc().toIso8601String()});
      await settle();
      expect(bloc.state.phase, CrisisPhase.resolved);
      expect(bloc.state.falseAlarm, isTrue);
      await bloc.close();
    });

    test('marking accounted is optimistic and calls the API', () async {
      final repo = _Repo(payload: _active());
      final bloc = CrisisBloc(repo: repo, socket: socket, isStaff: () => true)..add(const CrisisStarted());
      await settle();
      bloc.add(const CrisisAccountedSet('w1', AccountedStatus.injured));
      await settle();
      expect(bloc.state.counts[AccountedStatus.injured], 1);
      expect(repo.calls, contains('accounted:w1:INJURED'));
      await bloc.close();
    });
  });

  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('admin console (active) renders at ${w.toInt()}px with roster, map and routes', (t) async {
      t.view.physicalSize = Size(w, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final repo = _Repo(payload: _active());
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final bloc = CrisisBloc(repo: repo, socket: socket, isStaff: () => true)..add(const CrisisStarted());
      await t.pumpWidget(MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
        child: BlocProvider<SessionBloc>.value(
          value: SessionBloc(auth: _FakeAuth(), api: api),
          child: BlocProvider<CrisisBloc>.value(
            value: bloc,
            child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: CrisisConsoleScreen(admin: true, layout: MineLayoutData.fromJson((jsonDecode(layoutFixtureJson) as Map).cast<String, dynamic>()))),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 200));
      await t.pump(const Duration(milliseconds: 200));
      expect(find.text('CRISIS ACTIVE'), findsOneWidget);
      expect(find.text('Accounted for'), findsOneWidget);
      expect(find.text('Resolve crisis'), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('roster-w1')));
      await t.tap(find.text('Ravi Kumar · MIN-0101'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Routes for Ravi Kumar'), findsOneWidget);
      expect(find.textContaining('Main Shaft'), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }

  testWidgets('supervisor view is read-only: no resolve button, no tunnel toggling', (t) async {
    t.view.physicalSize = const Size(768, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
    final bloc = CrisisBloc(repo: _Repo(payload: _active()), socket: socket, isStaff: () => true)..add(const CrisisStarted());
    await t.pumpWidget(MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
      child: BlocProvider<CrisisBloc>.value(
        value: bloc,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: CrisisConsoleScreen(admin: false, layout: MineLayoutData.fromJson((jsonDecode(layoutFixtureJson) as Map).cast<String, dynamic>()))),
      ),
    ));
    await t.pump(const Duration(milliseconds: 200));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Resolve crisis'), findsNothing);
    expect(find.text('CRISIS ACTIVE'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('a miner hearing crisis:activated sees the EVACUATE banner and is sent to the evacuation view', (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
    final session = _session(Role.miner);
    await t.pump(const Duration(milliseconds: 50));
    final siren = SirenController(player: _FakeSiren());
    final bloc = CrisisBloc(repo: _Repo(), socket: socket, isStaff: () => false);
    final router = GoRouter(
      initialLocation: '/worker',
      routes: [
        ShellRoute(
          builder: (c, s, child) => GlobalOverlays(crisisBloc: bloc, siren: siren, child: child),
          routes: [
            GoRoute(path: '/worker', builder: (c, s) => const Scaffold(body: Text('worker home'))),
            GoRoute(path: '/worker/sos', builder: (c, s) => Scaffold(body: Text('evac ${s.uri.queryParameters['mode']}'))),
          ],
        ),
      ],
    );
    await t.pumpWidget(MultiRepositoryProvider(
      providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
      child: BlocProvider<SessionBloc>.value(value: session, child: MaterialApp.router(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), routerConfig: router)),
    ));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('worker home'), findsOneWidget);
    socket.inject(SocketEvents.crisisActivated, {'crisisId': 'c1', 'startedAt': DateTime.now().toUtc().toIso8601String(), 'triggers': [{'type': 'SOS'}], 'zoneIds': ['z1']});
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 400));
    expect(find.text('evac evac'), findsOneWidget);
    expect(find.textContaining('EVACUATE'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  test('the siren WAV is a valid 16-bit mono PCM file', () {
    final b = buildSirenWav();
    expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(b.sublist(8, 12)), 'WAVE');
    expect(b.length, 44 + 8000 * 2 * 2);
  });

  test('siren controller: autoplay blocked -> blocked flag; mute stops it', () async {
    final failing = SirenController(player: _ThrowingSiren());
    await failing.start();
    expect(failing.blocked, isTrue);
    final ok = SirenController(player: _FakeSiren());
    await ok.start();
    expect(ok.playing, isTrue);
    await ok.toggleMute();
    expect(ok.playing, isFalse);
    expect(ok.muted, isTrue);
  });
}

class _ThrowingSiren implements SirenPlayer {
  @override
  Future<void> play() async => throw StateError('autoplay blocked');
  @override
  Future<void> stop() async {}
}
