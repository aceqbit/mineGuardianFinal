import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/features/rewards/data/rewards_repository.dart';
import 'package:mine_guardian/features/rewards/view/rewards_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Repo implements RewardsRepository {
  @override
  Future<RewardsData> list({String? month}) async => const RewardsData(months: ['2026-02', '2026-01'], rewards: [
        RewardItem(id: '1', month: '2026-02', title: 'Safety Champion', rank: 1, score: 940, stars: 3, amountInr: 2000, extraHolidays: 1, workerName: 'Ravi Kumar', employeeId: 'MIN-0101', userId: 'u1'),
        RewardItem(id: '2', month: '2026-01', title: 'Safety Merit', rank: 3, score: 700, stars: 1, amountInr: 500, extraHolidays: 0, workerName: 'Ravi Kumar', employeeId: 'MIN-0101', userId: 'u1'),
      ]);
  @override
  Future<Map<String, dynamic>> publish(String month) async => {'created': 0, 'existing': 3};
}

void main() {
  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('rewards renders at ${w.toInt()}px and labels demo values', (t) async {
      t.view.physicalSize = Size(w, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final session = SessionBloc(auth: _FakeAuth(), api: api);
      await t.pumpWidget(BlocProvider<SessionBloc>.value(
        value: session,
        child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: RewardsScreen(repository: _Repo())),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Safety Champion'), findsOneWidget);
      expect(find.textContaining('demo value'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
}
