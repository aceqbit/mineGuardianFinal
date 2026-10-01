import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.number, this.subtitle});
  final String title;
  final Widget? action;
  final int? number;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (number != null) ...[
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.amber500, shape: BoxShape.circle),
              child: Text('$number', style: t.labelLarge?.copyWith(color: c.ink900)),
            ),
            const SizedBox(width: Space.md),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.headlineSmall),
              if (subtitle != null) Text(subtitle!, style: t.bodySmall),
            ]),
          ),
          ?action,
        ],
      ),
    );
  }
}
