import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/status_chip.dart';
import '../../../core/time/ist.dart';
import '../data/models/review_models.dart';

class ReportSections extends StatelessWidget {
  const ReportSections({super.key, required this.ai});
  final AiResult ai;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget list(String title, List<String> xs) => xs.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.labelMedium?.copyWith(color: c.muted)),
              for (final x in xs) Padding(padding: const EdgeInsets.only(top: 2), child: Text('• $x', style: t.bodyMedium)),
            ]),
          );
    return MgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('AI report', style: t.titleSmall),
          const SizedBox(height: Space.xs),
          Text(ai.summary.isEmpty ? 'No summary available.' : ai.summary, style: t.bodyMedium),
          list('Observations', ai.observations),
          list('Risks', ai.risks),
          list('Recommended actions', ai.actions),
          list('Conflicts between sources', ai.conflicts),
          list('Limitations', ai.limitations),
          if (ai.otherItems.isNotEmpty) list('Other PPE seen', [for (final i in ai.otherItems) '${i.key.label}: ${i.status.wire.toLowerCase()} (${(i.confidence * 100).round()}%)']),
          if (ai.tools.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [for (final tt in ai.tools) StatusChip(label: '${tt.name} ${tt.ms}ms', tone: tt.status == 'ok' ? ChipTone.neutral : ChipTone.warning)]),
            ),
          Padding(padding: const EdgeInsets.only(top: Space.sm), child: Text('${ai.model} · YOLO: ${ai.yoloProvider} · ${ai.latencyMs}ms', style: t.labelSmall?.copyWith(color: c.muted))),
        ],
      ),
    );
  }
}

class TimestampsPanel extends StatelessWidget {
  const TimestampsPanel({super.key, required this.facts, required this.recent});
  final CheckInFacts facts;
  final List<RecentDecision> recent;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 110, child: Text(k, style: t.bodySmall?.copyWith(color: c.muted))),
            Expanded(child: Text(v, style: t.bodyMedium)),
          ]),
        );
    String ts(DateTime? d) => d == null ? '—' : formatIstTime(d);
    return MgCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Capture details', style: t.titleSmall),
          const SizedBox(height: Space.xs),
          row('Captured', ts(facts.capturedAt)),
          row('Upload started', ts(facts.uploadedAt)),
          row('Received', ts(facts.receivedAt)),
          row('Source', facts.source),
          row('GPS', facts.accuracyM == null ? '—' : '±${facts.accuracyM!.round()} m'),
          row('In zone', facts.insideZone == null ? '—' : (facts.insideZone! ? 'Yes' : 'No')),
          row('In shift', facts.withinShift == null ? '—' : (facts.withinShift! ? 'Yes' : 'No')),
          if (facts.flags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Wrap(spacing: Space.xs, runSpacing: Space.xs, children: [for (final f in facts.flags) StatusChip(label: f.explanation, tone: ChipTone.warning, icon: Icons.flag)]),
            ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: Space.md),
            Text('Last ${recent.length} decisions', style: t.labelMedium?.copyWith(color: c.muted)),
            for (final r in recent)
              row(r.date == null ? '—' : formatIst(r.date!, pattern: 'dd MMM'), '${r.verdict?.label ?? '—'}${r.missing.isEmpty ? '' : ' · missing ${r.missing.map((k) => k.label).join(', ')}'}'),
          ],
        ],
      ),
    );
  }
}
