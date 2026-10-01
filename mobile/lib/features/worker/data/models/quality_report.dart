import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class QualityFailure extends Equatable {
  const QualityFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  List<Object?> get props => [code, message];
}

class QualityMetrics extends Equatable {
  const QualityMetrics({this.blurScore = 0, this.brightness = 0, this.clippedPct = 0, this.width = 0, this.height = 0, this.poseChecked = false, this.poseOk = false, this.missingLandmarks = const []});
  final double blurScore;
  final double brightness;
  final double clippedPct;
  final int width;
  final int height;
  final bool poseChecked;
  final bool poseOk;
  final List<String> missingLandmarks;

  QualityMetrics copyWith({bool? poseChecked, bool? poseOk, List<String>? missingLandmarks}) => QualityMetrics(
        blurScore: blurScore,
        brightness: brightness,
        clippedPct: clippedPct,
        width: width,
        height: height,
        poseChecked: poseChecked ?? this.poseChecked,
        poseOk: poseOk ?? this.poseOk,
        missingLandmarks: missingLandmarks ?? this.missingLandmarks,
      );

  /// `clientQuality` JSON sent with the upload.
  Map<String, dynamic> toJson() => {
        'blurScore': blurScore,
        'brightness': brightness,
        'width': width,
        'height': height,
        'poseChecked': poseChecked,
        'poseOk': poseOk,
        'missingLandmarks': missingLandmarks,
      };

  @override
  List<Object?> get props => [blurScore, brightness, clippedPct, width, height, poseChecked, poseOk, missingLandmarks];
}

class QualityReport extends Equatable {
  const QualityReport({
    required this.failures,
    required this.warnings,
    required this.metrics,
    required this.capturedAt,
    required this.exifTakenAt,
    required this.source,
    required this.sha256,
    required this.uploadBytes,
    required this.gateMs,
    this.uploadPath,
  });

  final List<QualityFailure> failures;
  final List<String> warnings;
  final QualityMetrics metrics;
  final DateTime? capturedAt;
  final DateTime? exifTakenAt;
  final String source; // camera | gallery
  final String sha256;
  final Uint8List uploadBytes;
  final String? uploadPath;
  final int gateMs;

  bool get pass => failures.isEmpty;
  QualityFailure? get firstFailure => failures.isEmpty ? null : failures.first;
  bool hasFailure(String code) => failures.any((f) => f.code == code);

  QualityReport copyWith({List<QualityFailure>? failures, QualityMetrics? metrics, List<String>? warnings, String? uploadPath, int? gateMs}) => QualityReport(
        failures: failures ?? this.failures,
        warnings: warnings ?? this.warnings,
        metrics: metrics ?? this.metrics,
        capturedAt: capturedAt,
        exifTakenAt: exifTakenAt,
        source: source,
        sha256: sha256,
        uploadBytes: uploadBytes,
        gateMs: gateMs ?? this.gateMs,
        uploadPath: uploadPath ?? this.uploadPath,
      );

  @override
  List<Object?> get props => [failures, warnings, metrics, capturedAt, exifTakenAt, source, sha256, gateMs, uploadPath];
}
