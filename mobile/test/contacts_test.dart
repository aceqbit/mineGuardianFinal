import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/tokens.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/auth/auth_repository.dart';
import 'package:mine_guardian/core/auth/session_bloc.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/contacts/data/contacts_repository.dart';
import 'package:mine_guardian/features/contacts/view/contacts_screen.dart';

class _FakeAuth implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation i) => null;
  @override
  get currentUser => null;
}

class _Repo implements ContactsRepository {
  final calls = <String>[];
  @override
  Future<List<EmergencyContactItem>> list() async => const [
        EmergencyContactItem(id: 'c1', category: ContactCategory.police, name: 'Police control room', displayNumber: '100 / 112', notes: 'Display only'),
        EmergencyContactItem(id: 'c2', category: ContactCategory.ambulance, name: 'Ambulance', displayNumber: '108'),
      ];
  @override
  Future<ContactActionResult> call(String id, {String? message}) async {
    calls.add('call:$id');
    return const ContactActionResult(ok: true, dryRun: true);
  }

  @override
  Future<ContactActionResult> sms(String id, {String? message}) async {
    calls.add('sms:$id');
    return const ContactActionResult(ok: true, dryRun: true);
  }

  @override
  Future<ContactActionResult> notifyAll({String? message}) async {
    calls.add('all');
    return const ContactActionResult(ok: true, dryRun: true, count: 2);
  }
}

void main() {
  test('tel: link uses only the first number and strips punctuation', () {
    const c = EmergencyContactItem(id: 'x', category: ContactCategory.police, name: 'P', displayNumber: '100 / 112');
    expect(c.telUri, 'tel:100');
    const d = EmergencyContactItem(id: 'y', category: ContactCategory.fire, name: 'D', displayNumber: '0326-2200000');
    expect(d.telUri, 'tel:03262200000');
  });

  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('contacts screen at ${w.toInt()}px: dialling needs the real-number warning', (t) async {
      t.view.physicalSize = Size(w, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final api = ApiClient(tokenProvider: ({bool forceRefresh = false}) async => null);
      final socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
      final opened = <Uri>[];
      final repo = _Repo();
      await t.pumpWidget(MultiRepositoryProvider(
        providers: [RepositoryProvider<ApiClient>.value(value: api), RepositoryProvider<SocketService>.value(value: socket)],
        child: BlocProvider<SessionBloc>.value(
          value: SessionBloc(auth: _FakeAuth(), api: api),
          child: MaterialApp(theme: ThemeData(useMaterial3: true, extensions: const [MgColors.light]), home: ContactsScreen(repository: repo, openUrl: (u) async => opened.add(u))),
        ),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text('Police control room'), findsOneWidget);
      expect(find.text('100 / 112'), findsOneWidget);
      await t.tap(find.text('Dial').first);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.text(realNumberWarning), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pump(const Duration(milliseconds: 300));
      expect(opened, isEmpty); // cancelling never dials
      await t.tap(find.text('Dial').first);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.widgetWithText(FilledButton, 'Dial'));
      await t.pump(const Duration(milliseconds: 300));
      expect(opened.single.toString(), 'tel:100');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
