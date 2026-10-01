import 'package:equatable/equatable.dart';

import '../data/models/feed_item.dart';
import 'supervisor_feed_event.dart';

enum FeedStatus { loading, ready, failure }

class SupervisorFeedState extends Equatable {
  const SupervisorFeedState({
    this.status = FeedStatus.loading,
    this.zoneId,
    this.zoneCode = '',
    this.zoneName = '',
    this.workers = const [],
    this.checkins = const [],
    this.hazards = const [],
    this.sos = const [],
    this.filter = FeedFilter.all,
    this.alertSeq = 0,
    this.error,
  });

  final FeedStatus status;
  final String? zoneId;
  final String zoneCode;
  final String zoneName;
  final List<WorkerToday> workers;
  final List<CheckinFeed> checkins;
  final List<HazardFeed> hazards;
  final List<SosFeed> sos;
  final FeedFilter filter;

  /// Increments on hazard:new / sos:triggered so the UI can fire a haptic.
  final int alertSeq;
  final String? error;

  int get checkedIn => workers.where((w) => w.status != 'NOT_CHECKED_IN').length;
  int get awaitingReview => checkins.where((c) => c.review == null || !c.review!.decided).length;
  int get openHazards => hazards.where((h) => h.status.wire == 'OPEN' || h.status.wire == 'ACKNOWLEDGED').length;

  /// All items merged and sorted: active SOS first, then emergencies, then newest.
  List<FeedItem> get items {
    final all = <FeedItem>[...sos, ...checkins, ...hazards];
    all.sort((a, b) {
      if (a.isSos != b.isSos) return a.isSos ? -1 : 1;
      if (a.isEmergency != b.isEmergency) return a.isEmergency ? -1 : 1;
      return b.time.compareTo(a.time);
    });
    switch (filter) {
      case FeedFilter.all:
        return all;
      case FeedFilter.checkins:
        return all.whereType<CheckinFeed>().toList();
      case FeedFilter.hazards:
        return all.whereType<HazardFeed>().toList();
      case FeedFilter.emergencies:
        return all.where((i) => i.isEmergency).toList();
    }
  }

  SupervisorFeedState copyWith({
    FeedStatus? status,
    String? zoneId,
    String? zoneCode,
    String? zoneName,
    List<WorkerToday>? workers,
    List<CheckinFeed>? checkins,
    List<HazardFeed>? hazards,
    List<SosFeed>? sos,
    FeedFilter? filter,
    int? alertSeq,
    String? error,
    bool clearError = false,
  }) =>
      SupervisorFeedState(
        status: status ?? this.status,
        zoneId: zoneId ?? this.zoneId,
        zoneCode: zoneCode ?? this.zoneCode,
        zoneName: zoneName ?? this.zoneName,
        workers: workers ?? this.workers,
        checkins: checkins ?? this.checkins,
        hazards: hazards ?? this.hazards,
        sos: sos ?? this.sos,
        filter: filter ?? this.filter,
        alertSeq: alertSeq ?? this.alertSeq,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [status, zoneId, zoneCode, zoneName, workers, checkins, hazards, sos, filter, alertSeq, error];
}

