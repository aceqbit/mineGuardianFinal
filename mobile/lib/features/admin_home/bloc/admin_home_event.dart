import 'package:equatable/equatable.dart';

sealed class AdminHomeEvent extends Equatable {
  const AdminHomeEvent();
  @override
  List<Object?> get props => [];
}

class AdminHomeStarted extends AdminHomeEvent {
  const AdminHomeStarted();
}

class AdminHomeRefreshRequested extends AdminHomeEvent {
  const AdminHomeRefreshRequested();
}

class AdminSocketEvent extends AdminHomeEvent {
  const AdminSocketEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [event, data];
}

class SupervisorsAssigned extends AdminHomeEvent {
  const SupervisorsAssigned(this.zoneId, this.supervisorIds);
  final String zoneId;
  final List<String> supervisorIds;
  @override
  List<Object?> get props => [zoneId, supervisorIds];
}

class AdminNoticeShown extends AdminHomeEvent {
  const AdminNoticeShown();
}
