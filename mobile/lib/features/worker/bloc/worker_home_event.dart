import 'package:equatable/equatable.dart';

sealed class WorkerHomeEvent extends Equatable {
  const WorkerHomeEvent();
  @override
  List<Object?> get props => [];
}

class WorkerHomeStarted extends WorkerHomeEvent {
  const WorkerHomeStarted();
}

class WorkerHomeRefreshed extends WorkerHomeEvent {
  const WorkerHomeRefreshed();
}

/// A live socket event for this worker (raw event name + data).
class WorkerHomeSocketEvent extends WorkerHomeEvent {
  const WorkerHomeSocketEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [event, data];
}

class WorkerHomeFlashCleared extends WorkerHomeEvent {
  const WorkerHomeFlashCleared(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}
