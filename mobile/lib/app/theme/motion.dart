import 'package:flutter/material.dart';

class Motion {
  Motion._();
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
  static const slower = Duration(milliseconds: 480);

  static const easeOut = Curves.easeOutCubic;
  static const easeIn = Curves.easeInCubic;
  static const emphasised = Cubic(0.2, 0, 0, 1);

  static const staggerStep = Duration(milliseconds: 40);
  static const maxStagger = 10;
  static const pressScale = 0.97;

  /// True when the user (or OS) asked for reduced motion.
  static bool reduce(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// A duration that collapses to zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) => reduce(context) ? Duration.zero : d;
}

/// Fade + 8 px slide entrance; index drives a 40 ms stagger (capped at 10 items).
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.slow);
  late final Animation<double> _a = CurvedAnimation(parent: _c, curve: Motion.easeOut);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduce(context)) {
      _c.value = 1;
      return;
    }
    final i = widget.index.clamp(0, Motion.maxStagger);
    Future<void>.delayed(Motion.staggerStep * i, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Opacity(
          opacity: _a.value,
          child: Transform.translate(offset: Offset(0, 8 * (1 - _a.value)), child: child),
        ),
        child: widget.child,
      );
}
