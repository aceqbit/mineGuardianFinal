import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/db/cache_repository.dart';
import 'package:mine_guardian/core/db/memory_outbox.dart';
import 'package:mine_guardian/core/db/outbox_item.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/core/sync/outbox_queue.dart';
import 'package:mine_guardian/core/sync/reachability.dart';
import 'package:mine_guardian/core/sync/sync_engine.dart';
import 'package:mine_guardian/features/worker/view/hazard_report_screen.dart';

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

void main() {
  for (final size in const [Size(360, 780), Size(768, 1024), Size(1280, 800)]) {
    testWidgets('hazard report renders at ${size.width.toInt()}px without overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final errs = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) => errs.add(d.toDiagnosticsNode().toStringDeep());
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
      final out = MemoryOutboxRepository();
      final engine = SyncEngine(outbox: out, sender: _NoSend(), reachability: _Reach());
      await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ApiClient>.value(value: api),
          RepositoryProvider<SocketService>.value(value: socket),
          RepositoryProvider<CacheRepository>.value(value: MemoryCacheRepository()),
          RepositoryProvider<SyncEngine>.value(value: engine),
          RepositoryProvider<OutboxQueue>.value(value: OutboxQueue(outbox: out, engine: engine)),
        ],
        child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: const HazardReportScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      FlutterError.onError = prev;
      tester.takeException();
      expect(errs, isEmpty, reason: errs.join('\n---\n'));
      expect(find.text('Gas leak / smell'), findsOneWidget);
      expect(find.text('Equipment failure'), findsOneWidget);
      expect(find.text('Report hazard'), findsOneWidget);
    });
  }
}
