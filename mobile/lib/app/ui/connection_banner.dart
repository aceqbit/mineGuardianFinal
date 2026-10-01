import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// Shows "Reconnecting…" once the socket has been disconnected for 2 s.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key, required this.connected});
  final Stream<bool> connected;

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  StreamSubscription<bool>? _sub;
  Timer? _timer;
  bool _show = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.connected.listen((ok) {
      _timer?.cancel();
      if (ok) {
        if (_show) setState(() => _show = false);
      } else {
        _timer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _show = true);
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AnimatedSize(
      duration: Motion.of(context, Motion.base),
      child: _show
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.lg),
              color: c.warningBg,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: c.warning)),
                const SizedBox(width: Space.sm),
                Text('Reconnecting…', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.warning)),
              ]),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}
