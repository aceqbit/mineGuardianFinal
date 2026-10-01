import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/motion.dart';

/// Animated 5-4-3-2-1 countdown with a haptic tick each second. Calls [onDone] at zero. Cancel by removing the widget.
class SelfTimer extends StatefulWidget {
  const SelfTimer({super.key, required this.onDone, this.seconds = 5});
  final VoidCallback onDone;
  final int seconds;

  @override
  State<SelfTimer> createState() => _SelfTimerState();
}

class _SelfTimerState extends State<SelfTimer> {
  late int _left = widget.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    HapticFeedback.selectionClick();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        widget.onDone();
      } else {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Photo in $_left seconds',
      child: Center(
        child: AnimatedSwitcher(
          duration: Motion.of(context, Motion.slow),
          transitionBuilder: (child, a) => ScaleTransition(scale: Tween(begin: 1.6, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
          child: Text('$_left', key: ValueKey(_left), style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white, fontSize: 120, shadows: const [Shadow(blurRadius: 16, color: Colors.black54)])),
        ),
      ),
    );
  }
}
