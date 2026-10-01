import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Grayscale copy (0..255 luminance) resized so its width is [targetWidth] (never enlarged).
class GrayImage {
  GrayImage(this.data, this.width, this.height);
  final Uint8List data;
  final int width;
  final int height;
}

GrayImage toGray(img.Image src, int targetWidth) {
  final resized = src.width > targetWidth ? img.copyResize(src, width: targetWidth, interpolation: img.Interpolation.average) : src;
  final w = resized.width;
  final h = resized.height;
  final out = Uint8List(w * h);
  var i = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = resized.getPixel(x, y);
      out[i++] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
    }
  }
  return GrayImage(out, w, h);
}

/// Variance of a 3x3 Laplacian ([0,1,0; 1,-4,1; 0,1,0]) over the interior pixels. Higher = sharper.
double laplacianVariance(Uint8List gray, int w, int h) {
  if (w < 3 || h < 3) return 0;
  var sum = 0.0;
  var sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    final row = y * w;
    for (var x = 1; x < w - 1; x++) {
      final v = gray[row - w + x] + gray[row + x - 1] + gray[row + x + 1] + gray[row + w + x] - 4 * gray[row + x];
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

class LightMetrics {
  const LightMetrics(this.mean, this.clippedFraction);
  final double mean;
  final double clippedFraction;
}

LightMetrics lightMetrics(Uint8List gray, {int low = 8, int high = 247}) {
  var sum = 0;
  var clipped = 0;
  for (final v in gray) {
    sum += v;
    if (v < low || v > high) clipped++;
  }
  return LightMetrics(sum / math.max(1, gray.length), clipped / math.max(1, gray.length));
}
