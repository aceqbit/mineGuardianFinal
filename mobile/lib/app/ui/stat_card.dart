import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'animated_counter.dart';
import 'mg_card.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.icon, this.suffix = '', this.tone, this.hint, this.onTap, this.prefix});
  final String label;
  final num? value;
  final IconData? icon;
  final String suffix;
  final String? prefix;
  final Color? tone;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final accent = tone ?? c.text;
    final card = MgCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 18, color: tone ?? c.muted), const SizedBox(width: Space.sm)],
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.labelMedium?.copyWith(color: c.muted))),
          ]),
          const SizedBox(height: Space.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (prefix != null) Text(prefix!, style: t.headlineMedium?.copyWith(color: accent)),
              AnimatedCounter(value: value, suffix: suffix, style: t.headlineMedium?.copyWith(color: accent)),
            ]),
          ),
          if (hint != null) Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ],
      ),
    );
    return Semantics(label: '$label ${value ?? 'not available'}$suffix', child: card);
  }
}
