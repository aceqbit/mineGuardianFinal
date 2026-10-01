import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../contracts/enums.dart';

sealed class HazardReportEvent extends Equatable {
  const HazardReportEvent();
  @override
  List<Object?> get props => [];
}

class HazardStarted extends HazardReportEvent {
  const HazardStarted();
}

class HazardPhotoSelected extends HazardReportEvent {
  const HazardPhotoSelected({required this.bytes, required this.source, this.shutterAt});
  final Uint8List bytes;
  final String source;
  final DateTime? shutterAt;
  @override
  List<Object?> get props => [bytes.length, source, shutterAt];
}

class HazardPhotoCleared extends HazardReportEvent {
  const HazardPhotoCleared();
}

class HazardCategorySelected extends HazardReportEvent {
  const HazardCategorySelected(this.category);
  final HazardCategory category;
  @override
  List<Object?> get props => [category];
}

class HazardLocationRefreshed extends HazardReportEvent {
  const HazardLocationRefreshed();
}

class HazardSubmitted extends HazardReportEvent {
  const HazardSubmitted();
}

class HazardRetry extends HazardReportEvent {
  const HazardRetry();
}

class HazardFlowProgress extends HazardReportEvent {
  const HazardFlowProgress(this.value);
  final double value;
  @override
  List<Object?> get props => [value];
}

class HazardAiResult extends HazardReportEvent {
  const HazardAiResult();
}

class HazardAiSlow extends HazardReportEvent {
  const HazardAiSlow();
}

class HazardQueuedSynced extends HazardReportEvent {
  const HazardQueuedSynced(this.hazardId);
  final String hazardId;
  @override
  List<Object?> get props => [hazardId];
}
