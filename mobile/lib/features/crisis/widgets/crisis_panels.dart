import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/status_chip.dart';
import '../../../contracts/enums.dart';
import '../../../core/time/ist.dart';
import '../data/crisis_models.dart';

String triggerLabel(String t) => switch (t) {
      'SOS' => 'SOS from a worker',
      'ML_EMERGENCY' => 'AI saw an emergency',
      'HAZARD_CRITICAL' => 'Critical hazard',
      'SUPERVISOR_ESCALATION' => 'Supervisor escalation',
      'MANUAL' => 'Started by admin',
      _ => t,
    };

class TriggerChips extends StatelessWidget {
  const TriggerChips({super.key, required this.triggers, required this.zoneCodes});
  final List<String> triggers;
  final List<String> zoneCodes;

  @override
  Widget build(BuildContext context) => Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
        for (final t in triggers) StatusChip(label: triggerLabel(t), tone: ChipTone.crisis, icon: Icons.bolt),
        for (final z in zoneCodes) StatusChip(label: z, tone: ChipTone.danger, icon: Icons.layers),
      ]);
}

Color statusColor(MgColors c, AccountedStatus s) => switch (s) { AccountedStatus.safe => c.success, AccountedStatus.missing => c.danger, AccountedStatus.injured => c.warning, AccountedStatus.unknown => c.muted };

/// Roster with an accounted-for status per worker. `onStatus` null = read only.
class RosterPanel extends StatelessWidget {
  const RosterPanel({super.key, required this.roster, required this.counts, required this.positions, required this.selected, required this.onSelect, this.onStatus});
  final List<RosterRow> roster;
  final Map<AccountedStatus, int> counts;
  final Map<String, CrisisPosition> positions;
  final String? selected;
  final ValueChanged<String> onSelect;
  final void Function(String workerId, AccountedStatus status)? onStatus;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    return MgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Accounted for', style: t.titleSmall),
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          StatusChip(label: 'Safe ${counts[AccountedStatus.safe]}', tone: ChipTone.success),
          StatusChip(label: 'Missing ${counts[AccountedStatus.missing]}', tone: ChipTone.danger),
          StatusChip(label: 'Injured ${counts[AccountedStatus.injured]}', tone: ChipTone.warning),
          StatusChip(label: 'Unknown ${counts[AccountedStatus.unknown]}'),
        ]),
        const SizedBox(height: Space.sm),
        if (roster.isEmpty) Text('No workers in the affected zones.', style: t.bodySmall?.copyWith(color: c.muted)),
        for (final r in roster)
          InkWell(
            key: ValueKey('roster-${r.userId}'),
            onTap: () => onSelect(r.userId),
            borderRadius: BorderRadius.circular(Radii.sm),
            child: Container(
              margin: const EdgeInsets.only(top: Space.xs),
              padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
              decoration: BoxDecoration(color: selected == r.userId ? c.amber50 : null, borderRadius: BorderRadius.circular(Radii.sm), border: Border.all(color: selected == r.userId ? c.amber500 : c.border)),
              child: Row(children: [
                Icon(positions.containsKey(r.userId) ? Icons.my_location : Icons.location_disabled, size: 16, color: positions.containsKey(r.userId) ? c.success : c.muted),
                const SizedBox(width: Space.sm),
                Expanded(child: Text('${r.name} · ${r.employeeId}', style: t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (onStatus == null)
                  Text(r.status.wire, style: t.labelSmall?.copyWith(color: statusColor(c, r.status), fontWeight: FontWeight.w800))
                else
                  PopupMenuButton<AccountedStatus>(
                    tooltip: 'Set status for ${r.name}',
                    initialValue: r.status,
                    onSelected: (s) => onStatus!(r.userId, s),
                    itemBuilder: (_) => [for (final s in AccountedStatus.values) PopupMenuItem(value: s, child: Text(s.wire))],
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: Space.sm), child: Text('${r.status.wire} ▾', style: t.labelMedium?.copyWith(color: statusColor(c, r.status), fontWeight: FontWeight.w800))),
                  ),
              ]),
            ),
          ),
      ]),
    );
  }
}

/// The selected worker's candidate routes with the reasons behind them. `onAssign` null = read only.
class RoutePanel extends StatelessWidget {
  const RoutePanel({super.key, required this.workerName, required this.routes, this.onAssign});
  final String? workerName;
  final List<CrisisRoute> routes;
  final void Function(CrisisRoute route)? onAssign;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    if (workerName == null) {
      return MgCard(child: Text('Tap a worker on the map or in the list to see their evacuation routes.', style: t.bodyMedium?.copyWith(color: c.muted)));
    }
    final sorted = [...routes]..sort((a, b) => a.rank.compareTo(b.rank));
    return MgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Routes for $workerName', style: t.titleSmall),
        if (sorted.isNotEmpty && sorted.first.positionUnknown) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text('No GPS fix yet. Routes start from the zone centre.', style: t.bodySmall?.copyWith(color: c.warning))),
        if (sorted.isEmpty) Padding(padding: const EdgeInsets.only(top: Space.sm), child: Text('No safe route found. Check blocked tunnels.', style: t.bodyMedium?.copyWith(color: c.danger))),
        for (final r in sorted)
          Container(
            margin: const EdgeInsets.only(top: Space.sm),
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(border: Border.all(color: r.recommended ? c.success : c.border), borderRadius: BorderRadius.circular(Radii.sm)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${r.recommended ? 'Recommended' : 'Backup ${r.rank}'} · ${r.exitName}', style: t.titleSmall)),
                Text('${(r.etaSec / 60).ceil()} min · ${r.distanceM} m', style: t.labelMedium),
              ]),
              const SizedBox(height: Space.xs),
              for (final reason in r.reasons) Text('• $reason', style: t.bodySmall?.copyWith(color: c.muted)),
              if (onAssign != null) Align(alignment: Alignment.centerRight, child: MgButton(label: 'Send to worker', kind: MgButtonKind.secondary, onPressed: () => onAssign!(r))),
            ]),
          ),
      ]),
    );
  }
}

class TimelinePanel extends StatelessWidget {
  const TimelinePanel({super.key, required this.lines});
  final List<TimelineLine> lines;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final shown = lines.reversed.take(40).toList();
    return MgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Timeline', style: t.titleSmall),
        const SizedBox(height: Space.sm),
        if (shown.isEmpty) Text('Nothing recorded yet.', style: t.bodySmall?.copyWith(color: c.muted)),
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 64, child: Text(l.at == null ? '' : formatIst(l.at!, pattern: 'HH:mm:ss'), style: t.bodySmall?.copyWith(color: c.muted))),
              Expanded(child: Text(l.text, style: t.bodySmall)),
            ]),
          ),
      ]),
    );
  }
}
