import 'dart:typed_data';

import 'package:equatable/equatable.dart';

sealed class CaptureEvent extends Equatable {
  const CaptureEvent();
  @override
  List<Object?> get props => [];
}

class CameraOpened extends CaptureEvent {
  const CameraOpened();
}

class CameraClosed extends CaptureEvent {
  const CameraClosed();
}

/// A photo was taken (camera) or picked (gallery); runs the quality gate.
class PhotoSelected extends CaptureEvent {
  const PhotoSelected({required this.bytes, required this.source, this.shutterAt});
  final Uint8List bytes;
  final String source;
  final DateTime? shutterAt;
  @override
  List<Object?> get props => [bytes.length, source, shutterAt];
}

/// Discard the current photo; attempt goes up by one.
class RetakeRequested extends CaptureEvent {
  const RetakeRequested({this.toCamera = false});
  final bool toCamera;
  @override
  List<Object?> get props => [toCamera];
}
