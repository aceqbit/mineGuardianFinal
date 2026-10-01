import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_card.dart';
import '../../../contracts/enums.dart';
import '../data/models/review_models.dart';

/// One row per required PPE item. The supervisor must choose Present / Absent for every row.
class ChecklistPanel extends StatelessWidget {
  const ChecklistPanel({super.key, required this.items, required this.selected, required this.onSelect, required this.readOnly, required this.decidedCount});
  final List<AiItem> items;
  final Map<PpeKey, PpeStatus> selected;
  final void Function(PpeKey, PpeStatus) onSelect;
  final bool readOnly;
  final int decidedCount;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return MgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text('Required PPE', style: Theme.of(context).textTheme.titleSmall)),
            Text('$decidedCount of ${items.length} decided', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
          ]),
          const SizedBox(height: Space.sm),
          for (final i in items) ChecklistRow(item: i, choice: selected[i.key], onSelect: readOnly ? null : (s) => onSelect(i.key, s)),
        ],
      ),
    );
  }
}

class ChecklistRow extends StatelessWidget {
  const ChecklistRow({super.key, required this.item, required this.choice, required this.onSelect});
  final AiItem item;
  final PpeStatus? choice;
  final ValueChanged<PpeStatus>? onSelect;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final differs = choice != null && choice != item.status;
    final aiLabel = switch (item.status) { PpeStatus.present => 'AI: present', PpeStatus.absent => 'AI: absent', _ => 'AI: uncertain' };
    return Container(
      key: ValueKey('row-${item.key.wire}'),
      margin: const EdgeInsets.only(top: Space.sm),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(
        border: Border.all(color: differs ? c.warning : c.border),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(item.key.icon, size: 20, color: c.muted),
            const SizedBox(width: Space.sm),
            Expanded(child: Text(item.key.label, style: Theme.of(context).textTheme.titleSmall)),
            Text('$aiLabel · ${(item.confidence * 100).round()}%', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.muted)),
          ]),
          if (item.evidence.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(item.evidence, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted))),
          const SizedBox(height: Space.sm),
          SegmentedButton<PpeStatus>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: PpeStatus.present, label: Text('Present')),
              ButtonSegment(value: PpeStatus.absent, label: Text('Absent')),
            ],
            selected: choice == null ? <PpeStatus>{} : {choice!},
            onSelectionChanged: onSelect == null ? null : (s) { if (s.isNotEmpty) onSelect!(s.first); },
          ),
          if (differs)
            Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text('Differs from AI', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.warning))),
        ],
      ),
    );
  }
}
