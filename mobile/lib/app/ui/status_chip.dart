import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'pulse_dot.dart';

enum ChipTone { neutral, success, warning, danger, info, crisis }

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.tone = ChipTone.neutral, this.icon});
  final String label;
  final ChipTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final (fg, bg) = switch (tone) {
      ChipTone.neutral => (c.muted, c.slate100.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1)),
      ChipTone.success => (c.success, c.successBg),
      ChipTone.warning => (c.warning, c.warningBg),
      ChipTone.danger => (c.danger, c.dangerBg),
      ChipTone.info => (c.info, c.infoBg),
      ChipTone.crisis => (Colors.white, c.crisis),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 1),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tone == ChipTone.crisis) ...[PulseDot(color: Colors.white, size: 6), const SizedBox(width: Space.xs)],
          if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: Space.xs)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg))),
        ],
      ),
    );
  }
}
