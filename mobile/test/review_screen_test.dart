import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/app/theme/app_theme.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/contracts/socket_events.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/compliance_review/bloc/review_bloc.dart';
import 'package:mine_guardian/features/compliance_review/bloc/review_event.dart';
import 'package:mine_guardian/features/compliance_review/data/models/review_models.dart';
import 'package:mine_guardian/features/compliance_review/data/review_repository.dart';
import 'package:mine_guardian/features/compliance_review/view/review_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Map<String, dynamic> _payload({bool decided = false}) => {
      'review': {
        'id': 'r1',
        'status': decided ? 'DECIDED' : 'PENDING',
        'ai': {
          'overallVerdict': 'NON_COMPLIANT',
          'overallConfidence': 0.82,
          'criticality': {'level': 'HIGH', 'score': 71, 'drivers': ['Helmet missing']},
          'emergency': {'detected': false, 'possible': false, 'type': 'NONE', 'evidence': ''},
          'items': [
            {'key': 'HELMET', 'required': true, 'status': 'ABSENT', 'confidence': 0.9, 'evidence': 'bare head'},
            {'key': 'REFLECTIVE_VEST', 'required': true, 'status': 'PRESENT', 'confidence': 0.8, 'evidence': 'vest visible'},
            {'key': 'GLOVES', 'required': true, 'status': 'UNCERTAIN', 'confidence': 0.4, 'evidence': 'hands hidden'},
          ],
          'summary': 'Helmet missing.',
          'report': {'observations': ['a'], 'risks': ['b'], 'recommendedActions': ['c']},
        },
        if (decided) 'decision': {'action': 'CONFIRM', 'finalVerdict': 'NON_COMPLIANT', 'note': '', 'agreedWithAi': true},
      },
      'checkIn': {'id': 'c1', 'imageUrl': null, 'source': 'camera'},
      'worker': {'fullName': 'Dinesh', 'employeeId': 'MIN-0105'},
      'zone': {'code': 'Z-B', 'name': 'Zone B', 'requiredPpe': ['HELMET', 'REFLECTIVE_VEST', 'GLOVES']},
      'recentDecisions': [],
    };

class _Repo implements ReviewRepository {
  _Repo({this.decided = false});
  final bool decided;
  Map<PpeKey, PpeStatus>? sentItems;
  DecisionAction? sentAction;

  @override
  Future<ReviewData> byCheckIn(String id) async => ReviewData.fromJson(_payload(decided: decided));
  @override
  Future<void> decide(String reviewId, {required DecisionAction action, EscalationLevel? level, required Map<PpeKey, PpeStatus> items, String? note}) async {
    sentAction = action;
    sentItems = items;
  }

  @override
  Future<String> reportUrl(String reviewId) async => 'https://example.test/r.pdf';
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late SocketService socket;
  setUp(() => socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x'));

  group('ReviewBloc', () {
    test('pre-selects only PRESENT/ABSENT rows with confidence >= 0.60', () async {
      final bloc = ReviewBloc(repo: _Repo(), socket: socket, checkInId: 'c1')..add(const ReviewLoaded());
      await settle();
      expect(bloc.state.selected, {PpeKey.helmet: PpeStatus.absent, PpeKey.reflectiveVest: PpeStatus.present});
      expect(bloc.state.allDecided, isFalse);
      expect(bloc.state.canConfirm, isFalse);
      await bloc.close();
    });

    test('confirm needs every row decided and none differing; a different choice enables override only', () async {
      final bloc = ReviewBloc(repo: _Repo(), socket: socket, checkInId: 'c1')..add(const ReviewLoaded());
      await settle();
      // UNCERTAIN AI row: any choice differs from the AI, so Confirm stays disabled.
      bloc.add(const ItemSelected(PpeKey.gloves, PpeStatus.present));
      await settle();
      expect(bloc.state.allDecided, isTrue);
      expect(bloc.state.canConfirm, isFalse);
      expect(bloc.state.canOverride, isTrue);
      await bloc.close();
    });

    test('submit sends every required row', () async {
      final repo = _Repo();
      final bloc = ReviewBloc(repo: repo, socket: socket, checkInId: 'c1')..add(const ReviewLoaded());
      await settle();
      bloc.add(const ItemSelected(PpeKey.gloves, PpeStatus.absent));
      bloc.add(const DecisionSubmitted(DecisionAction.overrideAction, note: 'gloves not worn at all'));
      await settle();
      expect(repo.sentAction, DecisionAction.overrideAction);
      expect(repo.sentItems!.length, 3);
      expect(bloc.state.done, isTrue);
      await bloc.close();
    });

    test('compliance:reviewed from another supervisor locks the card', () async {
      final bloc = ReviewBloc(repo: _Repo(), socket: socket, checkInId: 'c1')..add(const ReviewLoaded());
      await settle();
      socket.inject(SocketEvents.complianceReviewed, {'checkInId': 'c1', 'decidedBy': 'Meena', 'action': 'CONFIRM'});
      await settle();
      expect(bloc.state.locked, isTrue);
      expect(bloc.state.lockedBy, contains('Meena'));
      await bloc.close();
    });

    test('events for other check-ins are ignored', () async {
      final bloc = ReviewBloc(repo: _Repo(), socket: socket, checkInId: 'c1')..add(const ReviewLoaded());
      await settle();
      socket.inject(SocketEvents.complianceReviewed, {'checkInId': 'other', 'decidedBy': 'Meena', 'action': 'CONFIRM'});
      await settle();
      expect(bloc.state.locked, isFalse);
      await bloc.close();
    });
  });

  for (final w in [360.0, 768.0, 1280.0]) {
    testWidgets('review screen renders without overflow at ${w.toInt()}px', (t) async {
      t.view.physicalSize = Size(w, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(MultiRepositoryProvider(
 providers: [RepositoryProvider<SocketService>.value(value: socket), RepositoryProvider<ApiClient>.value(value: ApiClient(baseUrl: 'http://x', tokenProvider: ({bool forceRefresh = false}) async => null))],
        child: MaterialApp(theme: AppTheme.light(), home: ReviewScreen(checkInId: 'c1', repository: _Repo())),
      ));
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Required PPE'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('decided review shows read-only banner and no decision bar', (t) async {
    t.view.physicalSize = const Size(768, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MultiRepositoryProvider(
 providers: [RepositoryProvider<SocketService>.value(value: socket), RepositoryProvider<ApiClient>.value(value: ApiClient(baseUrl: 'http://x', tokenProvider: ({bool forceRefresh = false}) async => null))],
      child: MaterialApp(theme: AppTheme.light(), home: ReviewScreen(checkInId: 'c1', repository: _Repo(decided: true))),
    ));
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Confirm'), findsNothing);
    expect(find.textContaining('NON_COMPLIANT'.isEmpty ? '' : 'Non-compliant'), findsWidgets);
  });
}
