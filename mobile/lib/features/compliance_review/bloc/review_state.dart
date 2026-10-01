import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';
import '../data/models/review_models.dart';

enum ReviewStatus { loading, ready, notFound, failure }

class ReviewState extends Equatable {
  const ReviewState({this.status = ReviewStatus.loading, this.data, this.selected = const {}, this.submitting = false, this.done = false, this.lockedBy, this.error, this.message});
  final ReviewStatus status;
  final ReviewData? data;

  /// The supervisor's choice per required PPE key (absent = undecided).
  final Map<PpeKey, PpeStatus> selected;
  final bool submitting;
  final bool done;

  /// "Already reviewed by NAME, ACTION" when someone else decided while the card was open.
  final String? lockedBy;
  final String? error;
  final String? message;

  List<AiItem> get required => data?.ai.requiredItems ?? const [];
  int get decidedCount => required.where((i) => selected.containsKey(i.key)).length;
  bool get allDecided => required.isNotEmpty && decidedCount == required.length;

  /// A row differs from the AI when the choice != the AI status (an AI UNCERTAIN row always differs: it must be decided).
  bool differs(AiItem i) => selected.containsKey(i.key) && selected[i.key] != i.status;
  bool get anyDiffers => required.any(differs);
  bool get canConfirm => allDecided && !anyDiffers && !submitting && !(data?.decided ?? false);
  bool get canOverride => allDecided && anyDiffers && !submitting;
  bool get locked => lockedBy != null || (data?.decided ?? false) && !(data?.decision == null);

  ReviewState copyWith({ReviewStatus? status, ReviewData? data, Map<PpeKey, PpeStatus>? selected, bool? submitting, bool? done, String? lockedBy, String? error, String? message, bool clearMessages = false}) => ReviewState(
        status: status ?? this.status,
        data: data ?? this.data,
        selected: selected ?? this.selected,
        submitting: submitting ?? this.submitting,
        done: done ?? this.done,
        lockedBy: lockedBy ?? this.lockedBy,
        error: clearMessages ? null : (error ?? this.error),
        message: clearMessages ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [status, data, selected, submitting, done, lockedBy, error, message];
}
