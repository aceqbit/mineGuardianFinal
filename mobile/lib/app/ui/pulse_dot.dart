import 'package:flutter/material.dart';

import '../theme/motion.dart';

class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 10, this.pulsing = true});
  final Color color;
  final double size;
  final bool pulsing;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulsing && !Motion.reduce(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (widget.pulsing)
              Container(
                width: widget.size * (1 + 1.2 * _c.value),
                height: widget.size * (1 + 1.2 * _c.value),
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: 0.35 * (1 - _c.value))),
              ),
            Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
          ],
        ),
      ),
    );
  }
}
