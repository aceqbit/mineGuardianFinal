/// Client-side photo quality thresholds. Blur thresholds must be calibrated per device family:
/// shoot 5 sharp + 5 shaky photos, read the debug-printed scores and set the constant halfway between.
class QualityConfig {
  QualityConfig._();

  static const int minSidePx = 720;
  static const double darkBelow = 45;
  static const double brightAbove = 215;
  static const double clippedMaxFraction = 0.30; // fraction of pixels < 8 or > 247
  static const int clipLow = 8;
  static const int clipHigh = 247;

  static const double blurMinCheckin = 60;
  static const double blurMinHazard = 35;
  static const int blurGridPx = 512;
  static const int lightGridPx = 256;

  static const double poseMinLikelihood = 0.5;
  static const double poseXMin = 0.03, poseXMax = 0.97, poseYMin = 0.02, poseYMax = 0.98;
  static const double poseMinSpan = 0.45; // of image height
  static const double poseNoseTopFraction = 0.35;

  static const Duration staleAfter = Duration(minutes: 15);

  static const int uploadLongSidePx = 1600;
  static const int uploadJpegQuality = 85;
}

enum GateMode { checkin, hazard }
