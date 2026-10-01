import 'package:flutter_test/flutter_test.dart';
import 'package:mine_guardian/contracts/enums.dart';
import 'package:mine_guardian/contracts/socket_events.dart';
import 'package:mine_guardian/core/api/api_client.dart';
import 'package:mine_guardian/core/socket/socket_service.dart';
import 'package:mine_guardian/features/supervisor_home/bloc/supervisor_feed_bloc.dart';
import 'package:mine_guardian/features/supervisor_home/bloc/supervisor_feed_event.dart';
import 'package:mine_guardian/features/supervisor_home/data/feed_repository.dart';
import 'package:mine_guardian/features/supervisor_home/data/models/feed_item.dart';

class _Repo implements FeedRepository {
  bool failUpdate = false;
  int snapshots = 0;
  @override
  Future<FeedSnapshot> snapshot({String? zoneId}) async {
    snapshots++;
    return FeedSnapshot(
      zoneId: 'zB',
      zoneCode: 'Z-B',
      zoneName: 'Zone B',
      workers: const [WorkerToday(id: 'w1', fullName: 'Dinesh', employeeId: 'MIN-0105', status: 'NOT_CHECKED_IN')],
      checkins: const [],
      hazards: [HazardFeed(id: 'h1', reporterName: 'Dinesh', category: HazardCategory.electrical, time: DateTime.utc(2026, 1, 1, 10), status: HazardStatus.open)],
      sos: const [],
    );
  }

  @override
  Future<Map<String, RiskBand>> riskBands(String zoneId) async => const {};
  @override
  Future<HazardFeed> updateHazard(String id, HazardStatus status, {String? note}) async {
    if (failUpdate) throw ApiException(code: 'INVALID_TRANSITION', message: 'nope', statusCode: 409);
    return HazardFeed(id: id, reporterName: 'Dinesh', category: HazardCategory.electrical, time: DateTime.utc(2026, 1, 1, 10), status: status);
  }

  @override
  dynamic noSuchMethod(Invocation i) => null;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  late _Repo repo;
  late SocketService socket;
  late SupervisorFeedBloc bloc;

  setUp(() async {
    repo = _Repo();
    socket = SocketService(tokenProvider: ({bool forceRefresh = false}) async => null, url: 'http://x');
    bloc = SupervisorFeedBloc(repo: repo, socket: socket)..add(const FeedStarted());
    await settle();
  });
  tearDown(() => bloc.close());

  test('snapshot loads zone, workers and hazards', () {
    expect(bloc.state.zoneCode, 'Z-B');
    expect(bloc.state.workers.length, 1);
    expect(bloc.state.openHazards, 1);
  });

  test('checkin:new appears, compliance:predicted updates it in place, reviewed finishes it', () async {
    socket.inject(SocketEvents.checkinNew, {'checkInId': 'c1', 'workerId': 'w1', 'workerName': 'Dinesh', 'zoneId': 'zB', 'capturedAt': '2026-01-01T10:00:00Z', 'status': 'RECEIVED', 'integrityFlags': ['OFFLINE_DELAYED']});
    await settle();
    expect(bloc.state.checkins.single.review, isNull);
    expect(bloc.state.checkedIn, 1);
    expect(bloc.state.awaitingReview, 1);

    socket.inject(SocketEvents.compliancePredicted, {'checkInId': 'c1', 'reviewId': 'r1', 'workerId': 'w1', 'zoneId': 'zB', 'verdict': 'NON_COMPLIANT', 'overallConfidence': 0.91, 'criticality': {'level': 'HIGH', 'score': 58}, 'summary': 'Helmet absent', 'emergency': {'detected': false, 'possible': false}});
    await settle();
    final c = bloc.state.checkins.single;
    expect(bloc.state.checkins.length, 1); // updated in place, not duplicated
    expect(c.review!.verdict, Verdict.nonCompliant);
    expect(c.review!.critScore, 58);
    expect(c.status, CheckinStatus.predicted);

    socket.inject(SocketEvents.complianceReviewed, {'checkInId': 'c1', 'reviewId': 'r1', 'workerId': 'w1', 'zoneId': 'zB', 'finalVerdict': 'NON_COMPLIANT', 'action': 'CONFIRM'});
    await settle();
    expect(bloc.state.checkins.single.review!.decided, true);
    expect(bloc.state.awaitingReview, 0);
  });

  test('events for another zone are ignored', () async {
    socket.inject(SocketEvents.hazardNew, {'hazardId': 'hx', 'zoneId': 'zA', 'category': 'FIRE_SMOKE', 'reporterName': 'X', 'capturedAt': '2026-01-01T10:00:00Z'});
    await settle();
    expect(bloc.state.hazards.length, 1);
  });

  test('sort order: active SOS first, then emergencies, then newest; SOS bumps alertSeq', () async {
    socket.inject(SocketEvents.hazardNew, {'hazardId': 'h2', 'zoneId': 'zB', 'category': 'GAS_LEAK', 'reporterName': 'A', 'capturedAt': '2026-01-01T11:00:00Z'});
    await settle();
    socket.inject(SocketEvents.hazardClassified, {'hazardId': 'h1', 'zoneId': 'zB', 'severity': 'CRITICAL', 'summary': 'sparks', 'emergency': {'detected': true}});
    await settle();
    socket.inject(SocketEvents.sosTriggered, {'sosId': 's1', 'workerId': 'w1', 'workerName': 'Dinesh', 'zoneId': 'zB', 'triggeredAt': '2026-01-01T09:00:00Z'});
    await settle();
    final ids = bloc.state.items.map((i) => i.id).toList();
    expect(ids, ['s1', 'h1', 'h2']);
    expect(bloc.state.alertSeq, 2); // h2 + s1
    socket.inject(SocketEvents.sosCancelled, {'sosId': 's1', 'zoneId': 'zB'});
    await settle();
    expect(bloc.state.sos, isEmpty);
  });

  test('acknowledge is optimistic and rolls back on error', () async {
    repo.failUpdate = true;
    bloc.add(const HazardActionRequested('h1', HazardStatus.acknowledged));
    await settle();
    expect(bloc.state.hazards.single.status, HazardStatus.open); // rolled back
    expect(bloc.state.error, 'nope');
    repo.failUpdate = false;
    bloc.add(const HazardActionRequested('h1', HazardStatus.closed, note: 'made safe'));
    await settle();
    expect(bloc.state.hazards.single.status, HazardStatus.closed);
  });

  test('filters', () async {
    socket.inject(SocketEvents.checkinNew, {'checkInId': 'c1', 'workerId': 'w1', 'workerName': 'D', 'zoneId': 'zB', 'capturedAt': '2026-01-01T10:00:00Z', 'status': 'RECEIVED'});
    await settle();
    bloc.add(const FeedFilterChanged(FeedFilter.hazards));
    await settle();
    expect(bloc.state.items.every((i) => i is HazardFeed), true);
    bloc.add(const FeedFilterChanged(FeedFilter.checkins));
    await settle();
    expect(bloc.state.items.every((i) => i is CheckinFeed), true);
  });
}
