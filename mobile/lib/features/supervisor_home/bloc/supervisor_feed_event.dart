import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';

enum FeedFilter { all, checkins, hazards, emergencies }

sealed class SupervisorFeedEvent extends Equatable {
  const SupervisorFeedEvent();
  @override
  List<Object?> get props => [];
}

class FeedStarted extends SupervisorFeedEvent {
  const FeedStarted({this.zoneId});
  final String? zoneId;
  @override
  List<Object?> get props => [zoneId];
}

class FeedRefreshed extends SupervisorFeedEvent {
  const FeedRefreshed();
}

class FeedFilterChanged extends SupervisorFeedEvent {
  const FeedFilterChanged(this.filter);
  final FeedFilter filter;
  @override
  List<Object?> get props => [filter];
}

class FeedSocketEvent extends SupervisorFeedEvent {
  const FeedSocketEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [event, data];
}

class FeedReconnected extends SupervisorFeedEvent {
  const FeedReconnected();
}

class HazardActionRequested extends SupervisorFeedEvent {
  const HazardActionRequested(this.hazardId, this.status, {this.note});
  final String hazardId;
  final HazardStatus status;
  final String? note;
  @override
  List<Object?> get props => [hazardId, status, note];
}

class FeedErrorShown extends SupervisorFeedEvent {
  const FeedErrorShown();
}
