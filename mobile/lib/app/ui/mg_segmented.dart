import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

class MgSegment<T> {
  const MgSegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control with a sliding indicator. On compact widths the icon sits above a 12/16 label.
class MgSegmented<T> extends StatelessWidget {
  const MgSegmented({super.key, required this.segments, required this.value, required this.onChanged, this.stacked = false});
  final List<MgSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final idx = segments.indexWhere((s) => s.value == value).clamp(0, segments.length - 1);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth / segments.length;
      return Container(
        height: stacked ? 64 : 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.slate100.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1), borderRadius: BorderRadius.circular(Radii.sm + 2)),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: Motion.of(context, Motion.base),
              curve: Motion.easeOut,
              left: idx * (w - 8 / segments.length),
              width: w - 8 / segments.length,
              top: 0,
              bottom: 0,
              child: Container(decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.sm), boxShadow: Shadows.level(1))),
            ),
            Row(children: [
              for (final s in segments)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: s.value == value,
                    label: s.label,
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(Radii.sm),
                      onTap: () => onChanged(s.value),
                      child: Center(child: _item(context, s, s.value == value, c)),
                    ),
                  ),
                ),
            ]),
          ],
        ),
      );
    });
  }

  Widget _item(BuildContext context, MgSegment<T> s, bool selected, MgColors c) {
    final color = selected ? c.text : c.muted;
    final label = Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color));
    if (s.icon == null) return label;
    if (stacked) {
      return Column(mainAxisSize: MainAxisSize.min, children: [Icon(s.icon, size: 20, color: color), const SizedBox(height: 2), label]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(s.icon, size: 18, color: color), const SizedBox(width: Space.xs), Flexible(child: label)]);
  }
}
