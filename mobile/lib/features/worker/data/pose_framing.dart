import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import 'quality_config.dart';

class Landmark {
  const Landmark(this.x, this.y, this.likelihood);
  final double x; // pixels
  final double y;
  final double likelihood;
}

class FramingResult {
  const FramingResult({required this.ok, this.failureCode, this.message, this.missing = const []});
  final bool ok;
  final String? failureCode;
  final String? message;
  final List<String> missing;
}

const _required = ['nose', 'leftShoulder', 'rightShoulder', 'leftHip', 'rightHip', 'leftAnkle', 'rightAnkle'];

/// Pure framing rules (unit-testable): all required landmarks at >= 0.5 likelihood, inside 3..97% x and 2..98% y,
/// spanning >= 45% of the image height with the nose in the top 35%.
FramingResult evaluateFraming(Map<String, Landmark> lm, int width, int height) {
  bool seen(String k) => (lm[k]?.likelihood ?? 0) >= QualityConfig.poseMinLikelihood;
  final missing = _required.where((k) => !seen(k)).toList();
  final found = _required.length - missing.length;
  if (found < 3 || (missing.contains('nose') && missing.contains('leftShoulder') && missing.contains('rightShoulder'))) {
    return FramingResult(ok: false, failureCode: 'NO_PERSON', message: 'No person found — stand in front of the camera', missing: missing);
  }
  if (missing.contains('leftAnkle') || missing.contains('rightAnkle')) {
    return FramingResult(ok: false, failureCode: 'FEET_CUT', message: 'Feet not visible — step back', missing: missing);
  }
  if (missing.contains('nose')) {
    return FramingResult(ok: false, failureCode: 'HEAD_CUT', message: 'Head is cut off — tilt the phone up', missing: missing);
  }
  if (missing.isNotEmpty) {
    return FramingResult(ok: false, failureCode: 'OFF_CENTRE', message: 'Stand in the centre of the frame, head to boots', missing: missing);
  }
  var minY = double.infinity;
  var maxY = -double.infinity;
  for (final k in _required) {
    final p = lm[k]!;
    final nx = p.x / width;
    final ny = p.y / height;
    if (ny < QualityConfig.poseYMin && k == 'nose') {
      return const FramingResult(ok: false, failureCode: 'HEAD_CUT', message: 'Head is cut off — tilt the phone up');
    }
    if (ny > QualityConfig.poseYMax && k.endsWith('Ankle')) {
      return const FramingResult(ok: false, failureCode: 'FEET_CUT', message: 'Feet not visible — step back');
    }
    if (nx < QualityConfig.poseXMin || nx > QualityConfig.poseXMax || ny < QualityConfig.poseYMin || ny > QualityConfig.poseYMax) {
      return const FramingResult(ok: false, failureCode: 'OFF_CENTRE', message: 'Stand in the centre of the frame, head to boots');
    }
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  if ((maxY - minY) / height < QualityConfig.poseMinSpan) {
    return const FramingResult(ok: false, failureCode: 'TOO_FAR', message: 'Too far away — step closer');
  }
  if (lm['nose']!.y / height > QualityConfig.poseNoseTopFraction) {
    return const FramingResult(ok: false, failureCode: 'OFF_CENTRE', message: 'Stand upright with your head near the top of the frame');
  }
  return const FramingResult(ok: true);
}

/// ML Kit single-image pose detector. Android and iOS only; returns null when unavailable (web or detector error),
/// in which case the server re-checks.
class PoseFramingChecker {
  PoseDetector? _detector;

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<FramingResult?> check(String filePath, int width, int height) async {
    if (!supported) return null;
    try {
      _detector ??= PoseDetector(options: PoseDetectorOptions(model: PoseDetectionModel.base, mode: PoseDetectionMode.single));
      final poses = await _detector!.processImage(InputImage.fromFilePath(filePath));
      if (poses.isEmpty) {
        return const FramingResult(ok: false, failureCode: 'NO_PERSON', message: 'No person found — stand in front of the camera', missing: ['nose']);
      }
      final p = poses.first.landmarks;
      Landmark l(PoseLandmarkType t) {
        final v = p[t];
        return v == null ? const Landmark(0, 0, 0) : Landmark(v.x, v.y, v.likelihood);
      }

      return evaluateFraming({
        'nose': l(PoseLandmarkType.nose),
        'leftShoulder': l(PoseLandmarkType.leftShoulder),
        'rightShoulder': l(PoseLandmarkType.rightShoulder),
        'leftHip': l(PoseLandmarkType.leftHip),
        'rightHip': l(PoseLandmarkType.rightHip),
        'leftAnkle': l(PoseLandmarkType.leftAnkle),
        'rightAnkle': l(PoseLandmarkType.rightAnkle),
      }, width, height);
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async => _detector?.close();
}
