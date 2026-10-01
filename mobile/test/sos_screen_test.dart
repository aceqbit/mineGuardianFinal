import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/db/cache_repository.dart';
import 'package:mine_guardian/core/db/memory_outbox.dart';
import 'package:mine_guardian/core/db/outbox_item.dart';
import 'package:mine_guardian/core/location/location_service.dart';
import 'package:mine_guardian/core/models/session_user.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/core/sync/outbox_queue.dart';
import 'package:mine_guardian/core/sync/reachability.dart';
import 'package:mine_guardian/core/sync/sync_engine.dart';
import 'package:mine_guardian/features/sos/view/sos_screen.dart';

import 'fixtures/layout_fixture.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Offline implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<dynamic>? s, Future<void>? c) async => throw DioException.connectionError(requestOptions: o, reason: 'offline');
}

class _NoLoc extends LocationService {
  @override
  Future<LocationAccess> ensurePermission() async => LocationAccess.denied;
  @override
  Future<LocationFix?> getCurrent() async => null;
  @override
  Future<LocationFix?> lastKnown() async => null;
  @override
  Stream<LocationFix> stream({int distanceFilter = 5}) => const Stream.empty();
}

class _Reach implements Reachability {
  @override
  Stream<bool> get connectivity$ => const Stream.empty();
  @override
  Future<bool> hasConnection() async => false;
  @override
  Future<bool> canReachServer() async => false;
}

class _NoSend implements OutboxSender {
  @override
  Future<Map<String, dynamic>> send(OutboxItem item) async => {};
}

void main() {
  for (final evac in [false, true]) {
    for (final size in const [Size(360, 780), Size(1280, 800)]) {
      testWidgets('SOS screen (evac=$evac) at ${size.width.toInt()}px works offline with the cached map', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final errs = <String>[];
        final prev = FlutterError.onError;
        FlutterError.onError = (d) => errs.add(d.toDiagnosticsNode().toStringDeep());
        final auth = _FakeAuth();
        final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _Offline();
        final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null, dio: dio);
        final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
        final cache = MemoryCacheRepository();
        await cache.write(CacheKeys.layout, jsonDecode(layoutFixtureJson));
        final out = MemoryOutboxRepository();
        final engine = SyncEngine(outbox: out, sender: _NoSend(), reachability: _Reach());
        final session = SessionBloc(auth: auth, api: api)
          ..add(const LoggedIn(SessionUser(id: 'u1', role: Role.miner, fullName: 'Dinesh Oraon', employeeId: 'MIN-0105', phoneE164: '+919876500105', zoneId: 'z', zoneCode: 'Z-B', zoneName: 'Zone B', shift: Shift.b, zoneSupervisors: [ZoneSupervisor(name: 'Sunil Banerjee', e164: '+919876500012')])));
        await tester.pumpWidget(MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ApiClient>.value(value: api),
            RepositoryProvider<SocketService>.value(value: socket),
            RepositoryProvider<CacheRepository>.value(value: cache),
            RepositoryProvider<SyncEngine>.value(value: engine),
            RepositoryProvider<OutboxQueue>.value(value: OutboxQueue(outbox: out, engine: engine)),
          ],
          child: BlocProvider<SessionBloc>.value(value: session, child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: SosScreen(evacOnly: evac, locationService: _NoLoc()))),
        ));
        await tester.pump(const Duration(milliseconds: 800));
        FlutterError.onError = prev;
        expect(find.text(evac ? 'EVACUATION ACTIVE' : 'SOS ACTIVE'), findsOneWidget);
        expect(find.text('Call supervisor'), findsOneWidget);
        expect(find.text('First aid'), findsOneWidget);
        expect(find.textContaining('Go to '), findsOneWidget); // on-device route from the cached layout
        if (!evac) {
          expect(find.textContaining('Saved offline'), findsOneWidget);
          expect((await out.all()).where((i) => i.kind == OutboxKind.sos).length, 1);
        } else {
          expect((await out.all()), isEmpty); // evac mode sends nothing
        }
        await tester.pumpWidget(const SizedBox());
        tester.takeException();
        expect(errs, isEmpty, reason: errs.join('\n---\n'));
      });
    }
  }
}
