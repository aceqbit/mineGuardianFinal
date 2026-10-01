import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mine_guardian/features/worker/data/image_metrics.dart';
import 'package:mine_guardian/features/worker/data/pose_framing.dart';
import 'package:mine_guardian/features/worker/data/quality_config.dart';
import 'package:mine_guardian/features/worker/data/quality_gate.dart';

img.Image checker({int size = 512, int cell = 8}) {
  final im = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final v = ((x ~/ cell) + (y ~/ cell)).isEven ? 230 : 40;
      im.setPixelRgb(x, y, v, v, v);
    }
  }
  return im;
}

img.Image solid(int v, {int size = 800}) {
  final im = img.Image(width: size, height: size);
  img.fill(im, color: img.ColorRgb8(v, v, v));
  return im;
}

void main() {
  test('checkerboard has a high blur score; blurred is below 25% of sharp', () {
    final g1 = toGray(checker(), 512);
    final s = laplacianVariance(g1.data, g1.width, g1.height);
    final g2 = toGray(img.gaussianBlur(checker(), radius: 6), 512);
    final b = laplacianVariance(g2.data, g2.width, g2.height);
    expect(s, greaterThan(1000));
    expect(b, lessThan(s * 0.25));
  });

  test('all black -> DARK, all white -> BRIGHT', () async {
    final black = Uint8List.fromList(img.encodeJpg(solid(0), quality: 90));
    final white = Uint8List.fromList(img.encodeJpg(solid(255), quality: 90));
    final rb = await runGatePure(GateInput(bytes: black, source: 'camera', mode: GateMode.checkin));
    final rw = await runGatePure(GateInput(bytes: white, source: 'camera', mode: GateMode.checkin));
    expect(rb.failures.map((f) => f.code), contains('DARK'));
    expect(rw.failures.map((f) => f.code), contains('BRIGHT'));
  });

  test('small image fails RESOLUTION_LOW; stale gallery photo fails STALE; no EXIF only warns', () async {
    final small = Uint8List.fromList(img.encodeJpg(checker(size: 400), quality: 90));
    final r = await runGatePure(GateInput(bytes: small, source: 'camera', mode: GateMode.checkin));
    expect(r.failures.map((f) => f.code), contains('RESOLUTION_LOW'));

    final ok = Uint8List.fromList(img.encodeJpg(checker(size: 800, cell: 10), quality: 92));
    final now = DateTime.utc(2026, 1, 1, 10, 0);
    final stale = await runGatePure(GateInput(bytes: ok, source: 'gallery', mode: GateMode.hazard, exifTakenAt: now.subtract(const Duration(minutes: 30)), nowUtc: now));
    expect(stale.failures.map((f) => f.code), contains('STALE'));
    final noExif = await runGatePure(GateInput(bytes: ok, source: 'gallery', mode: GateMode.hazard, nowUtc: now));
    expect(noExif.failures.map((f) => f.code), isNot(contains('STALE')));
    expect(noExif.warnings, contains('NO_EXIF'));
  });

  test('upload is JPEG <= 1600 px with sha256', () async {
    final big = Uint8List.fromList(img.encodeJpg(checker(size: 2000, cell: 20), quality: 90));
    final r = await runGatePure(GateInput(bytes: big, source: 'camera', mode: GateMode.hazard));
    expect(r.metrics.width, QualityConfig.uploadLongSidePx);
    expect(r.sha256.length, 64);
  });

  group('framing', () {
    Map<String, Landmark> person({double noseY = 0.1, double ankleY = 0.9}) => {
          'nose': Landmark(500, noseY * 1000, 0.9),
          'leftShoulder': const Landmark(450, 250, 0.9),
          'rightShoulder': const Landmark(550, 250, 0.9),
          'leftHip': const Landmark(460, 500, 0.9),
          'rightHip': const Landmark(540, 500, 0.9),
          'leftAnkle': Landmark(470, ankleY * 1000, 0.9),
          'rightAnkle': Landmark(530, ankleY * 1000, 0.9),
        };
    test('full body passes', () => expect(evaluateFraming(person(), 1000, 1000).ok, true));
    test('feet missing -> FEET_CUT', () {
      final p = person()..['leftAnkle'] = const Landmark(470, 900, 0.1);
      expect(evaluateFraming(p, 1000, 1000).failureCode, 'FEET_CUT');
    });
    test('head missing -> HEAD_CUT', () {
      final p = person()..['nose'] = const Landmark(500, 100, 0.1);
      expect(evaluateFraming(p, 1000, 1000).failureCode, 'HEAD_CUT');
    });
    test('small person -> TOO_FAR', () => expect(evaluateFraming(person(noseY: 0.3, ankleY: 0.6), 1000, 1000).failureCode, 'TOO_FAR'));
    test('nobody -> NO_PERSON', () => expect(evaluateFraming({}, 1000, 1000).failureCode, 'NO_PERSON'));
  });
}
