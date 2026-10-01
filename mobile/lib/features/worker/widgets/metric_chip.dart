import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';

enum MetricState { checking, pass, fail, neutral }

/// One quality metric. Animates from a spinner to green / red; [delay] staggers the reveal (80 ms steps).
class MetricChip extends StatefulWidget {
  const MetricChip({super.key, required this.label, required this.state, this.detail, this.delay = Duration.zero});
  final String label;
  final MetricState state;
  final String? detail;
  final Duration delay;

  @override
  State<MetricChip> createState() => _MetricChipState();
}

class _MetricChipState extends State<MetricChip> {
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    if (widget.state == MetricState.checking) return;
    Future<void>.delayed(widget.delay, () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  @override
  void didUpdateWidget(covariant MetricChip old) {
    super.didUpdateWidget(old);
    if (old.state == MetricState.checking && widget.state != MetricState.checking) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _revealed = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final shown = widget.state == MetricState.checking || !_revealed ? MetricState.checking : widget.state;
    final (fg, bg, icon) = switch (shown) {
      MetricState.checking => (c.muted, c.slate100.withValues(alpha: 1), null),
      MetricState.pass => (c.success, c.successBg, Icons.check_circle),
      MetricState.fail => (c.danger, c.dangerBg, Icons.cancel),
      MetricState.neutral => (c.muted, c.slate100.withValues(alpha: 1), Icons.remove_circle_outline),
    };
    return Semantics(
      label: '${widget.label}: ${shown.name}${widget.detail != null ? ', ${widget.detail}' : ''}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.base),
            child: icon == null ? SizedBox(key: const ValueKey('s'), width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg)) : Icon(icon, key: ValueKey(shown), size: 18, color: fg),
          ),
          const SizedBox(width: Space.sm),
          Text(widget.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
          if (widget.detail != null && shown != MetricState.checking) ...[
            const SizedBox(width: Space.xs),
            Text(widget.detail!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: fg)),
          ],
        ]),
      ),
    );
  }
}
