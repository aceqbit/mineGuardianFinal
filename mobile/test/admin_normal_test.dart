import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/admin_normal/data/admin_normal_repository.dart';
import 'package:mine_guardian/features/admin_normal/view/admin_normal_screen.dart';
import 'package:mine_guardian/features/admin_normal/view/reports_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Repo implements AdminNormalRepository {
  @override
  Future<SlaOverview> sla() async => const SlaOverview(
        pending: 2,
        supervisors: [SupervisorReliability(id: 's1', fullName: 'Ramesh Prasad', zoneCode: 'Z-A', decided: 10, onTime: 9, breaches: 1, noData: false, reliability: 85)],
        breaches: [SlaReview(reviewId: 'r1', zoneCode: 'Z-A', workerName: 'Ravi Kumar', breached: true)],
      );
  @override
  Future<HazardAudit> hazardAudit({int days = 7}) async => const HazardAudit(total: 3, byStatus: {'OPEN': 1}, medianAckMinutes: 4, slowOpen: 1, hazards: [
        HazardAuditRow(id: 'h1', category: 'GAS_LEAK', severity: 'CRITICAL', status: 'OPEN', zoneCode: 'Z-A', reporter: 'Ravi Kumar', slow: true),
      ]);
  @override
  Future<List<ReportRow>> reports() async => const [ReportRow(id: 'p1', day: '2026-03-10', compliancePct: 80, reviewed: 10)];
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> pump(WidgetTester t, double w, Widget child) async {
  t.view.physicalSize = Size(w, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
  final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
  final session = SessionBloc(auth: _FakeAuth(), api: api);
  await t.pumpWidget(MultiRepositoryProvider(
    providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
    child: BlocProvider<SessionBloc>.value(value: session, child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: child)),
  ));
  await t.pump(const Duration(milliseconds: 100));
  await t.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('normal mode renders at ${w.toInt()}px', (t) async {
      await pump(t, w, AdminNormalScreen(repository: _Repo()));
      expect(find.text('Ramesh Prasad'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.textContaining('Breached'), findsOneWidget);
      await t.tap(find.text('Hazard audit'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('GAS LEAK'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('reports renders at ${w.toInt()}px', (t) async {
      await pump(t, w, ReportsScreen(repository: _Repo()));
      expect(find.text('2026-03-10'), findsOneWidget);
      expect(find.textContaining('80% compliant'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
