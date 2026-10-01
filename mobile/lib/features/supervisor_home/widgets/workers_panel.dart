import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/status_chip.dart';
import '../../../contracts/enums.dart';
import '../data/models/feed_item.dart';

(String, ChipTone) workerChip(WorkerToday w) {
  switch (w.status) {
    case 'NOT_CHECKED_IN':
      return ('Not checked in', ChipTone.neutral);
    case 'RECEIVED':
    case 'ANALYZING':
      return ('AI checking', ChipTone.info);
    case 'PREDICTED':
      return ('Awaiting review', ChipTone.warning);
    case 'FAILED_AI':
      return ('Manual review', ChipTone.warning);
    case 'REVIEWED':
      return w.finalVerdict == Verdict.nonCompliant ? ('Non-compliant', ChipTone.danger) : ('Compliant', ChipTone.success);
    default:
      return (w.status, ChipTone.neutral);
  }
}

/// The zone's miners with today's status chip, a risk dot (hidden when scoring is not live yet) and a call button.
class WorkersPanel extends StatelessWidget {
  const WorkersPanel({super.key, required this.workers});
  final List<WorkerToday> workers;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    if (workers.isEmpty) return const EmptyState(icon: Icons.groups, title: 'No workers in this zone');
    return Column(children: [
      for (final w in workers)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: c.border)),
            child: Row(children: [
              if (w.riskBand != null)
                Tooltip(
                  message: 'Risk ${w.riskBand!.wire.toLowerCase()}',
                  child: Container(width: 10, height: 10, margin: const EdgeInsets.only(right: Space.sm), decoration: BoxDecoration(shape: BoxShape.circle, color: switch (w.riskBand!) { RiskBand.green => c.success, RiskBand.amber => c.warning, RiskBand.red => c.danger })),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(w.fullName, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleMedium),
                  Text(w.employeeId, style: t.bodySmall),
                ]),
              ),
              Builder(builder: (_) {
                final (label, tone) = workerChip(w);
                return Flexible(child: StatusChip(label: label, tone: tone));
              }),
              if (w.phone != null) IconButton(tooltip: 'Call ${w.fullName}', icon: const Icon(Icons.call), onPressed: () => launchUrl(Uri(scheme: 'tel', path: w.phone))),
            ]),
          ),
        ),
    ]);
  }
}
