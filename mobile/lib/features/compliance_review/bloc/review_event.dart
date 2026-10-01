import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';

sealed class ReviewEvent extends Equatable {
  const ReviewEvent();
  @override
  List<Object?> get props => [];
}

class ReviewLoaded extends ReviewEvent {
  const ReviewLoaded();
}

class ItemSelected extends ReviewEvent {
  const ItemSelected(this.key, this.status);
  final PpeKey key;
  final PpeStatus status;
  @override
  List<Object?> get props => [key, status];
}

class DecisionSubmitted extends ReviewEvent {
  const DecisionSubmitted(this.action, {this.level, this.note});
  final DecisionAction action;
  final EscalationLevel? level;
  final String? note;
  @override
  List<Object?> get props => [action, level, note];
}

class ReviewSocketEvent extends ReviewEvent {
  const ReviewSocketEvent(this.event, this.data);
  final String event;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [event, data];
}

class ReviewNoticeShown extends ReviewEvent {
  const ReviewNoticeShown();
}
