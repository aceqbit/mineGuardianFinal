import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/section_header.dart';
import '../../../app/ui/skeleton.dart';
import '../../../app/ui/status_chip.dart';
import '../../../contracts/enums.dart';
import '../../../contracts/routes.dart';
import '../../../core/api/api_client.dart';
import '../../../core/time/ist.dart';
import '../data/feed_repository.dart';
import '../data/models/feed_item.dart';
import '../widgets/close_note_sheet.dart';
import '../widgets/hazard_card.dart';

class HazardDetailScreen extends StatefulWidget {
  const HazardDetailScreen({super.key, required this.hazardId, this.initial});
  final String hazardId;
  final HazardFeed? initial;

  @override
  State<HazardDetailScreen> createState() => _HazardDetailScreenState();
}

class _HazardDetailScreenState extends State<HazardDetailScreen> {
  HazardFeed? _h;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _h = widget.initial;
    if (_h == null) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final h = await FeedRepository(api: context.read<ApiClient>()).hazardById(widget.hazardId);
      if (mounted) setState(() => _h = h);
      if (h == null && mounted) setState(() => _failed = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(HazardStatus s) async {
    String? note;
    if (s != HazardStatus.acknowledged) {
      note = await showCloseNoteSheet(context, action: s);
      if (note == null || !mounted) return;
    }
    final repo = FeedRepository(api: context.read<ApiClient>());
    try {
      final saved = await repo.updateHazard(widget.hazardId, s, note: note);
      if (mounted) setState(() => _h = saved);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final h = _h;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Hazard'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.canPop() ? context.pop() : context.go(Routes.supervisor))),
      body: h == null
          ? (_loading ? const Padding(padding: EdgeInsets.all(Space.lg), child: SkeletonList(count: 3, itemHeight: 120)) : EmptyState(icon: Icons.search_off, title: _failed ? 'Hazard not found' : 'Loading…', actionLabel: 'Retry', onAction: _load))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: Space.lg),
              child: ContentWidth(
                maxWidth: 1000,
                child: Builder(builder: (context) {
                  final image = ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.card),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Hero(
                        tag: 'hazard-${h.id}',
                        child: h.thumbUrl == null
                            ? ColoredBox(color: c.border, child: Icon(h.category.icon, size: 48, color: c.muted))
                            : InteractiveViewer(minScale: 1, maxScale: 5, child: CachedNetworkImage(imageUrl: h.thumbUrl!, fit: BoxFit.cover, placeholder: (_, _) => const Skeleton(radius: 0), errorWidget: (_, _, _) => Icon(Icons.broken_image, color: c.muted))),
                      ),
                    ),
                  );
                  Widget tl(String label, DateTime? at, {bool done = false}) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: Space.xs),
                        child: Row(children: [
                          Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, size: 18, color: done ? c.success : c.muted),
                          const SizedBox(width: Space.sm),
                          Expanded(child: Text(label, style: t.bodyMedium)),
                          Text(at == null ? '—' : formatIstTime(at), style: t.bodySmall),
                        ]),
                      );
                  final details = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [Icon(h.category.icon, color: c.danger), const SizedBox(width: Space.sm), Expanded(child: Text(h.category.label, style: t.headlineSmall))]),
                    const SizedBox(height: Space.sm),
                    Wrap(spacing: Space.sm, children: [
                      if (h.severity != null) StatusChip(label: h.severity!.wire, tone: severityTone(h.severity)),
                      StatusChip(label: h.status.wire, tone: statusTone(h.status)),
                    ]),
                    const SizedBox(height: Space.md),
                    Text('Reported by ${h.reporterName}', style: t.bodyMedium),
                    Text(formatIstTime(h.time), style: t.bodySmall),
                    if (h.lat != null) ...[
                      const SizedBox(height: Space.md),
                      Row(children: [
                        Expanded(child: Text('${h.lat!.toStringAsFixed(5)}, ${h.lng!.toStringAsFixed(5)}', style: t.bodyMedium)),
                        MgButton(label: 'Open in Maps', icon: Icons.map, kind: MgButtonKind.secondary, onPressed: () => launchUrl(Uri.parse('https://maps.google.com/?q=${h.lat},${h.lng}'), mode: LaunchMode.externalApplication)),
                      ]),
                    ],
                    if (h.aiSummary != null) ...[const SizedBox(height: Space.lg), const SectionHeader(title: 'AI assessment'), MgCard(child: Text(h.aiSummary!, style: t.bodyMedium))],
                    const SizedBox(height: Space.lg),
                    const SectionHeader(title: 'Status timeline'),
                    MgCard(child: Column(children: [
                      tl('Opened', h.time, done: true),
                      tl('Acknowledged', h.acknowledgedAt, done: h.acknowledgedAt != null),
                      tl(h.status == HazardStatus.rejected ? 'Rejected' : 'Closed', h.closedAt, done: h.closedAt != null),
                    ])),
                    if (h.closeNote != null && h.closeNote!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Space.md), child: Text('Note: ${h.closeNote}', style: t.bodyMedium)),
                    if (h.status == HazardStatus.open || h.status == HazardStatus.acknowledged) ...[
                      const SizedBox(height: Space.lg),
                      Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                        if (h.status == HazardStatus.open) MgButton(label: 'Acknowledge', kind: MgButtonKind.secondary, onPressed: () => _act(HazardStatus.acknowledged)),
                        MgButton(label: 'Close', onPressed: () => _act(HazardStatus.closed)),
                        MgButton(label: 'Reject', kind: MgButtonKind.ghost, onPressed: () => _act(HazardStatus.rejected)),
                      ]),
                    ],
                  ]);
                  if (context.isCompact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [image, const SizedBox(height: Space.lg), details]);
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 5, child: image), const SizedBox(width: Space.x2), Expanded(flex: 6, child: details)]);
                }),
              ),
            ),
    );
  }
}
