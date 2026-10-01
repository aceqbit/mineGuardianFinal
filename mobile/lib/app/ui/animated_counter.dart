import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Counts from the previous value to [value]. `null` renders an em dash.
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({super.key, required this.value, this.style, this.suffix = '', this.placeholder = '—'});
  final num? value;
  final TextStyle? style;
  final String suffix;
  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final st = style ?? Theme.of(context).textTheme.headlineMedium;
    if (v == null) return Text(placeholder, style: st);
    if (Motion.reduce(context)) return Text('${v.round()}$suffix', style: st);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: v.toDouble()),
      duration: Motion.slower,
      curve: Motion.easeOut,
      builder: (context, val, _) => Text('${val.round()}$suffix', style: st),
    );
  }
}
