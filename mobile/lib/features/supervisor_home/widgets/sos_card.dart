import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/pulse_dot.dart';
import '../../../core/time/ist.dart';
import '../data/models/feed_item.dart';

class SosCard extends StatelessWidget {
  const SosCard({super.key, required this.item, required this.onOpenCrisis});
  final SosFeed item;
  final VoidCallback onOpenCrisis;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.crisis, borderRadius: BorderRadius.circular(Radii.card), boxShadow: Shadows.level(2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const PulseDot(color: Colors.white, size: 12),
          const SizedBox(width: Space.md),
          Expanded(child: Text('SOS · ${item.workerName}', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800))),
          Tooltip(message: formatIstTime(item.time), child: Text(relativeTime(item.time), style: t.bodySmall?.copyWith(color: Colors.white70))),
        ]),
        if (item.lat != null) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text('${item.lat!.toStringAsFixed(5)}, ${item.lng!.toStringAsFixed(5)}', style: t.bodySmall?.copyWith(color: Colors.white70))),
        const SizedBox(height: Space.md),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          if (item.lat != null) MgButton(label: 'Open in Maps', icon: Icons.map, kind: MgButtonKind.secondary, onPressed: () => launchUrl(Uri.parse('https://maps.google.com/?q=${item.lat},${item.lng}'), mode: LaunchMode.externalApplication)),
          if (item.phone != null) MgButton(label: 'Call worker', icon: Icons.call, kind: MgButtonKind.secondary, onPressed: () => launchUrl(Uri(scheme: 'tel', path: item.phone))),
          MgButton(label: 'Open crisis view', icon: Icons.warning, onPressed: onOpenCrisis),
        ]),
      ]),
    );
  }
}
