import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';

/// Head / shoulders / body / legs outline at 70% of the preview height with a subtle animated dash.
class SilhouetteOverlay extends StatefulWidget {
  const SilhouetteOverlay({super.key});

  @override
  State<SilhouetteOverlay> createState() => _SilhouetteOverlayState();
}

class _SilhouetteOverlayState extends State<SilhouetteOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduce(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: _c, builder: (context, _) => CustomPaint(painter: _SilhouettePainter(_c.value), size: Size.infinite)),
      );
}

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter(this.phase);
  final double phase;

  Path _outline(Size s) {
    final h = s.height * 0.70;
    final top = (s.height - h) / 2;
    final cx = s.width / 2;
    final u = h / 100; // 1% of outline height
    final p = Path();
    // head
    p.addOval(Rect.fromCenter(center: Offset(cx, top + 8 * u), width: 14 * u, height: 16 * u));
    // shoulders + torso
    p.moveTo(cx - 6 * u, top + 17 * u);
    p.cubicTo(cx - 18 * u, top + 19 * u, cx - 22 * u, top + 24 * u, cx - 22 * u, top + 34 * u);
    p.lineTo(cx - 20 * u, top + 52 * u);
    p.lineTo(cx - 9 * u, top + 54 * u);
    // legs
    p.lineTo(cx - 10 * u, top + 98 * u);
    p.lineTo(cx - 2 * u, top + 98 * u);
    p.lineTo(cx, top + 62 * u);
    p.lineTo(cx + 2 * u, top + 98 * u);
    p.lineTo(cx + 10 * u, top + 98 * u);
    p.lineTo(cx + 9 * u, top + 54 * u);
    p.lineTo(cx + 20 * u, top + 52 * u);
    p.lineTo(cx + 22 * u, top + 34 * u);
    p.cubicTo(cx + 22 * u, top + 24 * u, cx + 18 * u, top + 19 * u, cx + 6 * u, top + 17 * u);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const dash = 12.0;
    const gap = 8.0;
    for (final PathMetric m in _outline(size).computeMetrics()) {
      var d = phase * (dash + gap);
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, (d + dash).clamp(0, m.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) => old.phase != phase;
}
