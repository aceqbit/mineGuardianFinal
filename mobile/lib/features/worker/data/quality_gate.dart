import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../../../core/time/ist.dart';
import 'exif_reader.dart';
import 'image_metrics.dart';
import 'models/quality_report.dart';
import 'pose_framing.dart';
import 'quality_config.dart';

class GateInput {
  const GateInput({required this.bytes, required this.source, required this.mode, this.exifTakenAt, this.nowUtc});
  final Uint8List bytes;
  final String source;
  final GateMode mode;
  final DateTime? exifTakenAt;
  final DateTime? nowUtc;
}

class GateOutput {
  const GateOutput({required this.failures, required this.warnings, required this.metrics, required this.uploadBytes, required this.sha256, required this.exifTakenAt});
  final List<QualityFailure> failures;
  final List<String> warnings;
  final QualityMetrics metrics;
  final Uint8List uploadBytes;
  final String sha256;
  final DateTime? exifTakenAt;
}

/// Runs in a background isolate: EXIF, orientation, resolution, lighting, sharpness, freshness, upload preparation.
Future<GateOutput> runGatePure(GateInput input) async {
  final failures = <QualityFailure>[];
  final warnings = <String>[];

  final exif = input.exifTakenAt ?? await readExifTakenAt(input.bytes);
  var decoded = img.decodeImage(input.bytes);
  if (decoded == null) {
    return GateOutput(
      failures: const [QualityFailure('UNREADABLE', 'This photo could not be read — try another')],
      warnings: warnings,
      metrics: const QualityMetrics(),
      uploadBytes: input.bytes,
      sha256: sha256.convert(input.bytes).toString(),
      exifTakenAt: exif,
    );
  }
  decoded = img.bakeOrientation(decoded);
  final width = decoded.width;
  final height = decoded.height;

  if (width < QualityConfig.minSidePx || height < QualityConfig.minSidePx) {
    failures.add(const QualityFailure('RESOLUTION_LOW', 'Photo is too small — use the back camera and move closer'));
  }

  final light = toGray(decoded, QualityConfig.lightGridPx);
  final lm = lightMetrics(light.data, low: QualityConfig.clipLow, high: QualityConfig.clipHigh);
  if (lm.mean < QualityConfig.darkBelow) {
    failures.add(const QualityFailure('DARK', 'Too dark — switch on your cap lamp or move to a lit area'));
  } else if (lm.mean > QualityConfig.brightAbove) {
    failures.add(const QualityFailure('BRIGHT', "Too bright — don't point at a lamp"));
  } else if (lm.clippedFraction > QualityConfig.clippedMaxFraction) {
    failures.add(const QualityFailure('EXPOSURE', 'Uneven lighting — avoid strong glare and deep shadow'));
  }

  final sharp = toGray(decoded, QualityConfig.blurGridPx);
  final blur = laplacianVariance(sharp.data, sharp.width, sharp.height);
  final blurMin = input.mode == GateMode.checkin ? QualityConfig.blurMinCheckin : QualityConfig.blurMinHazard;
  if (kDebugMode) debugPrint('[quality] blurScore=${blur.toStringAsFixed(1)} brightness=${lm.mean.toStringAsFixed(1)} min=$blurMin');
  if (blur < blurMin) {
    failures.add(const QualityFailure('BLURRY', 'Photo is blurred — hold steady and retake'));
  }

  final now = input.nowUtc ?? DateTime.now().toUtc();
  if (input.source == 'gallery') {
    if (exif == null) {
      warnings.add('NO_EXIF');
    } else if (now.difference(exif) > QualityConfig.staleAfter) {
      failures.add(QualityFailure('STALE', 'This photo was taken at ${formatIst(exif)} — capture a fresh one for this shift'));
    }
  }

  // Upload copy: long side <= 1600, JPEG q85.
  var out = decoded;
  final longSide = width > height ? width : height;
  if (longSide > QualityConfig.uploadLongSidePx) {
    out = width >= height ? img.copyResize(decoded, width: QualityConfig.uploadLongSidePx) : img.copyResize(decoded, height: QualityConfig.uploadLongSidePx);
  }
  final uploadBytes = Uint8List.fromList(img.encodeJpg(out, quality: QualityConfig.uploadJpegQuality));

  return GateOutput(
    failures: failures,
    warnings: warnings,
    metrics: QualityMetrics(blurScore: blur, brightness: lm.mean, clippedPct: lm.clippedFraction * 100, width: out.width, height: out.height),
    uploadBytes: uploadBytes,
    sha256: sha256.convert(uploadBytes).toString(),
    exifTakenAt: exif,
  );
}

Future<GateOutput> _entry(GateInput i) => runGatePure(i);

class QualityGate {
  QualityGate({PoseFramingChecker? pose}) : _pose = pose ?? PoseFramingChecker();
  final PoseFramingChecker _pose;

  /// For camera photos [shutterAt] is the shutter moment (capturedAt). For gallery photos capturedAt is the EXIF time (or null).
  Future<QualityReport> evaluate({required Uint8List bytes, required String source, required GateMode mode, DateTime? shutterAt}) async {
    final t0 = DateTime.now();
    final out = await compute(_entry, GateInput(bytes: bytes, source: source, mode: mode));
    final failures = [...out.failures];
    var metrics = out.metrics;
    String? uploadPath;

    final unreadable = failures.any((f) => f.code == 'UNREADABLE');
    if (!unreadable && !kIsWeb) {
      try {
        final dir = await getTemporaryDirectory();
        final f = File('${dir.path}/upload_${DateTime.now().microsecondsSinceEpoch}.jpg');
        await f.writeAsBytes(out.uploadBytes, flush: true);
        uploadPath = f.path;
      } catch (_) {}
    }

    // Framing (check-ins on Android/iOS): ML Kit runs on the main isolate (platform channel).
    if (mode == GateMode.checkin && !unreadable && _pose.supported && uploadPath != null) {
      final res = await _pose.check(uploadPath, metrics.width, metrics.height);
      if (res == null) {
        metrics = metrics.copyWith(poseChecked: false);
      } else {
        metrics = metrics.copyWith(poseChecked: true, poseOk: res.ok, missingLandmarks: res.missing);
        if (!res.ok) {
          final idx = failures.indexWhere((x) => x.code == 'STALE'); // framing sits before freshness
          final fail = QualityFailure(res.failureCode ?? 'NO_PERSON', res.message ?? 'Stand in the frame, head to boots');
          if (idx < 0) {
            failures.add(fail);
          } else {
            failures.insert(idx, fail);
          }
        }
      }
    }

    final capturedAt = source == 'camera' ? (shutterAt ?? DateTime.now()).toUtc() : out.exifTakenAt;

    return QualityReport(
      failures: failures,
      warnings: out.warnings,
      metrics: metrics,
      capturedAt: capturedAt,
      exifTakenAt: out.exifTakenAt,
      source: source,
      sha256: out.sha256,
      uploadBytes: out.uploadBytes,
      uploadPath: uploadPath,
      gateMs: DateTime.now().difference(t0).inMilliseconds,
    );
  }

  Future<void> dispose() => _pose.dispose();
}
