import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/pulse_dot.dart';
import '../../../core/time/ist.dart';
import '../data/admin_repository.dart';

/// Calm green when no crisis; pulsing red with the console link while one is active.
class CrisisStatusCard extends StatelessWidget {
  const CrisisStatusCard({super.key, required this.crisis, required this.onOpenConsole});
  final ActiveCrisisRef? crisis;
  final VoidCallback onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final active = crisis != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: active ? c.crisis : c.successBg, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: active ? c.crisis : c.success.withValues(alpha: 0.3))),
      child: LayoutBuilder(builder: (context, box) {
        final stacked = box.maxWidth < 560;
        final text = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(active ? 'Crisis active since ${formatIst(crisis!.startedAt)} · ${crisis!.trigger.replaceAll('_', ' ')}' : 'All clear — crisis mode is off', style: t.titleMedium?.copyWith(color: active ? Colors.white : c.success)),
          if (!active) Text('Crisis mode turns on automatically on SOS, AI emergency, critical hazard or escalation', style: t.bodySmall?.copyWith(color: c.success)),
        ]);
        final dot = PulseDot(color: active ? Colors.white : c.success, size: 12, pulsing: active);
        final button = active ? MgButton(label: 'Open crisis console', icon: Icons.crisis_alert, onPressed: onOpenConsole) : null;
        if (stacked) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [dot, const SizedBox(width: Space.md), Expanded(child: text)]),
            if (button != null) ...[const SizedBox(height: Space.md), button],
          ]);
        }
        return Row(children: [dot, const SizedBox(width: Space.md), Expanded(child: text), ?button]);
      }),
    );
  }
}
