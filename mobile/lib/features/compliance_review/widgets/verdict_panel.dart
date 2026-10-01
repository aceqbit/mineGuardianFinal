import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/status_chip.dart';
import '../../../contracts/enums.dart';
import '../data/models/review_models.dart';

class CriticalityGauge extends StatelessWidget {
  const CriticalityGauge({super.key, required this.level, required this.score});
  final Criticality level;
  final int score;

  static Color colorFor(MgColors c, Criticality l) => switch (l) {
        Criticality.none || Criticality.low => c.success,
        Criticality.medium => c.warning,
        Criticality.high || Criticality.critical => c.danger,
      };

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final color = colorFor(c, level);
    return Semantics(
      label: 'Criticality ${level.wire}, score $score of 100',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Criticality', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.muted)),
            const Spacer(),
            Text('${level.wire} · $score', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: Space.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.pill),
            child: LinearProgressIndicator(value: (score.clamp(0, 100)) / 100, minHeight: 8, color: color, backgroundColor: c.slate100),
          ),
        ],
      ),
    );
  }
}

class VerdictPanel extends StatelessWidget {
  const VerdictPanel({super.key, required this.ai});
  final AiResult ai;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final v = ai.verdict;
    final tone = switch (v) { Verdict.compliant => ChipTone.success, Verdict.nonCompliant => ChipTone.danger, _ => ChipTone.warning };
    return MgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(spacing: Space.sm, runSpacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            StatusChip(label: 'AI: ${v?.label ?? 'No result'}', tone: tone),
            Text('${(ai.confidence * 100).round()}% confidence', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
          ]),
          const SizedBox(height: Space.md),
          CriticalityGauge(level: ai.critLevel, score: ai.critScore),
          if (ai.drivers.isNotEmpty) ...[
            const SizedBox(height: Space.sm),
            Text(ai.drivers.join(' · '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
          ],
          if (ai.emergencyDetected || ai.emergencyPossible) ...[
            const SizedBox(height: Space.md),
            Container(
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(color: c.dangerBg, borderRadius: BorderRadius.circular(Radii.sm)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.warning_amber, color: c.danger),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    '${ai.emergencyDetected ? 'Possible emergency detected' : 'Emergency suspected'}: ${ai.emergencyType.wire}. ${ai.emergencyEvidence} Supervisor decides — escalate if real.',
                    style: TextStyle(color: c.danger),
                  ),
                ),
              ]),
            ),
          ],
          if (ai.error != null) ...[
            const SizedBox(height: Space.md),
            Text('AI note: ${ai.error}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.warning)),
          ],
        ],
      ),
    );
  }
}
