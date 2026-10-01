import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/models/session_user.dart';
import 'package:mine_guardian/core/db/memory_outbox.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/core/sync/reachability.dart';
import 'package:mine_guardian/core/sync/sync_engine.dart';
import 'package:mine_guardian/core/db/outbox_item.dart';
import 'package:mine_guardian/features/worker/view/worker_home_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Reach implements Reachability {
  @override
  Stream<bool> get connectivity$ => const Stream.empty();
  @override
  Future<bool> hasConnection() async => true;
  @override
  Future<bool> canReachServer() async => true;
}

class _NoSend implements OutboxSender {
  @override
  Future<Map<String, dynamic>> send(OutboxItem item) async => {};
}

class _NotFound implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      ResponseBody.fromString(jsonEncode({'error': {'code': 'NOT_FOUND', 'message': 'nf'}}), 404, headers: {Headers.contentTypeHeader: ['application/json']});
}

void main() {
  for (final size in const [Size(360, 780), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('worker home at ${size.width.toInt()}px shows neutral stats without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errs = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(d.toDiagnosticsNode().toStringDeep());
      addTearDown(() => FlutterError.onError = prev);
      final auth = _FakeAuth();
      final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _NotFound();
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null, dio: dio);
      final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
      final session = SessionBloc(auth: auth, api: api)
        ..add(const LoggedIn(SessionUser(id: 'u1', role: Role.miner, fullName: 'Dinesh Oraon', employeeId: 'MIN-0105', phoneE164: '+919876500105', zoneId: 'z', zoneCode: 'Z-B', zoneName: 'Zone B — Central Panel', shift: Shift.b)));
      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket), RepositoryProvider<SyncEngine>.value(value: SyncEngine(outbox: MemoryOutboxRepository(), sender: _NoSend(), reachability: _Reach()))],
        child: BlocProvider<SessionBloc>.value(
          value: session,
          child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: const WorkerHomeScreen()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      FlutterError.onError = prev;
      tester.takeException();
      expect(errs, isEmpty, reason: errs.join('\n---\n'));
      expect(find.text('Hi Dinesh'), findsOneWidget);
      expect(find.text('—'), findsWidgets);
      expect(find.text('Not submitted today'), findsOneWidget);
      expect(find.text('No check-ins yet'), findsOneWidget);
    });
  }
}
