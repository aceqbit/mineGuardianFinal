import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/socket_events.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/leaderboard/data/leaderboard_repository.dart';
import 'package:mine_guardian/features/leaderboard/view/leaderboard_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

LeaderRow _r(String id, String name, int score, int rank) => LeaderRow(userId: id, name: name, employeeId: 'MIN-$id', score: score, streak: 3, xp: 40, rank: rank);

class _Repo implements LeaderboardRepository {
  @override
  Future<List<LeaderRow>> workers() async => [_r('1', 'Asha Rao', 940, 1), _r('2', 'Dinesh K', 810, 2), _r('3', 'Meena S', 700, 3)];
  @override
  Future<List<LeaderRow>> supervisors() async => const [];
  @override
  Future<MyStanding> me() async => const MyStanding(rank: 2, total: 3, score: 810, streak: 3, xp: 40, badges: ['STREAK_7'], gapToNext: 130);
}

void main() {
  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('leaderboard renders at ${w.toInt()}px with my standing and rows', (t) async {
      t.view.physicalSize = Size(w, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final session = SessionBloc(auth: _FakeAuth(), api: api);
      await t.pumpWidget(MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
        child: BlocProvider<SessionBloc>.value(
          value: session,
          child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: LeaderboardScreen(repository: _Repo())),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 800));
      expect(find.text('#2 of 3'), findsOneWidget);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(t.takeException(), isNull);

      // a live leaderboard:updated replaces the list
      socket.inject(SocketEvents.leaderboardUpdated, {
        'top': [
          {'userId': '9', 'name': 'Zed New', 'employeeId': 'MIN-9', 'score': 990, 'streak': 9, 'xp': 90, 'rank': 1},
        ],
      });
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Zed New'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  }
}
