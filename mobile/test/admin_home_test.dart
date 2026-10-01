import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/admin_home/view/admin_home_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Adapter implements HttpClientAdapter {
  _Adapter(this.crisis);
  final bool crisis;
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final Object body = o.path.endsWith('/supervisors')
        ? [
            {'id': 's1', 'fullName': 'Ramesh Prasad', 'zoneId': 'z1', 'phoneMasked': '+91******0011'},
            {'id': 's2', 'fullName': 'Sunil Banerjee', 'zoneId': 'z2', 'phoneMasked': '+91******0012'},
          ]
        : {
            'counts': {'workers': 12, 'supervisors': 3, 'zones': 2},
            'openHazards': 4,
            'todayCompliancePct': null,
            'pendingReviews': null,
            'activeCrisis': crisis ? {'id': 'c1', 'startedAt': '2026-01-01T10:00:00Z', 'trigger': {'type': 'SOS'}, 'zoneIds': ['z2']} : null,
            'zones': [
              {'id': 'z1', 'code': 'Z-A', 'name': 'Zone A — West Panel', 'supervisors': [{'id': 's1', 'fullName': 'Ramesh Prasad', 'phoneMasked': '+91******0011'}], 'minersCount': 4, 'checkedInToday': 2},
              {'id': 'z2', 'code': 'Z-B', 'name': 'Zone B — Central Panel', 'supervisors': [], 'minersCount': 4, 'checkedInToday': 0},
            ],
          };
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {Headers.contentTypeHeader: ['application/json']});
  }
}

void main() {
  for (final crisis in [false, true]) {
    for (final size in const [Size(360, 780), Size(768, 1024), Size(1280, 800)]) {
      testWidgets('admin home (crisis=$crisis) at ${size.width.toInt()}px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errs = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => errs.add(d.toDiagnosticsNode().toStringDeep());
        final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _Adapter(crisis);
        final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null, dio: dio);
        final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
        final session = SessionBloc(auth: _FakeAuth(), api: api);
        await tester.pumpWidget(MultiRepositoryProvider(
          providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
          child: BlocProvider<SessionBloc>.value(value: session, child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: const AdminHomeScreen())),
        ));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 800));
        FlutterError.onError = prev;
        expect(find.text('Zone A — West Panel'), findsOneWidget);
        expect(find.text('Manage supervisors'), findsNWidgets(2));
        expect(find.text(crisis ? 'Open crisis console' : 'All clear — crisis mode is off'), findsOneWidget);
        expect(find.text('—'), findsWidgets); // compliance % and pending reviews are null
        await tester.pumpWidget(const SizedBox());
        tester.takeException();
        expect(errs, isEmpty, reason: errs.join('\n---\n'));
      });
    }
  }
}
