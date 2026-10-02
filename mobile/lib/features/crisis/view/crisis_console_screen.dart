import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/toast.dart';
import '../../../config.dart';
import '../../../contracts/enums.dart';
import '../../../contracts/routes.dart';
import '../../../core/api/api_client.dart';
import '../../../core/db/cache_repository.dart';
import '../../../core/db/layout_repository.dart';
import '../../../core/models/mine_layout.dart';
import '../../../core/time/ist.dart';
import '../../admin_home/data/admin_repository.dart';
import '../../admin_home/widgets/admin_nav.dart';
import '../bloc/crisis_bloc.dart';
import '../widgets/crisis_map.dart';
import '../widgets/crisis_panels.dart';
import '../widgets/resolve_dialog.dart';

/// `/admin/crisis` (full control) and `/crisis/view` (supervisors: read-only map and roster; they can mark workers accounted for).
class CrisisConsoleScreen extends StatefulWidget {
  const CrisisConsoleScreen({super.key, required this.admin, this.layout, this.zones, this.openUrl});
  final bool admin;

  /// Tests inject these; the app loads them.
  final MineLayoutData? layout;
  final List<ZoneOverview>? zones;
  final Future<void> Function(Uri)? openUrl;

  @override
  State<CrisisConsoleScreen> createState() => _CrisisConsoleScreenState();
}

class _CrisisConsoleScreenState extends State<CrisisConsoleScreen> {
  MineLayoutData? _layout;
  String? _selected;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _layout = widget.layout;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_layout == null && widget.layout == null) {
      LayoutRepository(api: context.read<ApiClient>(), cache: context.read<CacheRepository>()).load().then((l) {
        if (mounted) setState(() => _layout = l);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = BlocConsumer<CrisisBloc, CrisisState>(
      listenWhen: (a, b) => a.notice != b.notice && b.notice != null,
      listener: (context, s) {
        Toast.show(context, s.notice!, kind: s.noticeIsError ? ToastKind.error : ToastKind.success);
        context.read<CrisisBloc>().add(const CrisisNoticeShown());
      },
      builder: (context, s) => switch (s.phase) {
        CrisisPhase.idle => _Idle(admin: widget.admin, zones: widget.zones),
        CrisisPhase.active => _Active(state: s, admin: widget.admin, layout: _layout, selected: _selected, onSelect: (id) => setState(() => _selected = id), openUrl: widget.openUrl),
        CrisisPhase.resolved => _Resolved(state: s, admin: widget.admin, openUrl: widget.openUrl),
      },
    );
    if (widget.admin) return AdminScaffold(section: AdminSection.crisis, title: 'Crisis console', body: body);
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: 'Back', onPressed: () => context.canPop() ? context.pop() : context.go(Routes.supervisor)), title: const Text('Crisis view')),
      body: body,
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle({required this.admin, this.zones});
  final bool admin;
  final List<ZoneOverview>? zones;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Center(
      child: ContentWidth(
        maxWidth: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_user, size: 56, color: c.success),
          const SizedBox(height: Space.md),
          Text('No active crisis', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: Space.xs),
          Text('Crisis mode turns on by itself when a worker sends an SOS, the AI sees an emergency, or a critical hazard is reported.', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.muted)),
          if (admin) ...[
            const SizedBox(height: Space.x2),
            MgButton(label: 'Activate crisis mode manually', kind: MgButtonKind.danger, icon: Icons.crisis_alert, onPressed: () => _activate(context)),
          ],
        ]),
      ),
    );
  }

  Future<void> _activate(BuildContext context) async {
    final bloc = context.read<CrisisBloc>();
    final list = zones ?? (await AdminRepository(api: context.read<ApiClient>()).overview()).zones;
    if (!context.mounted) return;
    final picked = <String>{};
    final note = TextEditingController();
    final res = await showDialog<(List<String>, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Activate crisis mode'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('This calls and texts supervisors and admins, and tells every worker to evacuate.'),
              for (final z in list) CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: Text('${z.code} · ${z.name}'), value: picked.contains(z.id), onChanged: (v) => set(() => v == true ? picked.add(z.id) : picked.remove(z.id))),
              TextField(controller: note, maxLength: 300, onChanged: (_) => set(() {}), decoration: const InputDecoration(labelText: 'Reason', helperText: 'At least 10 characters')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: MgColors.of(ctx).crisis), onPressed: picked.isEmpty || note.text.trim().length < 10 ? null : () => Navigator.pop(ctx, (picked.toList(), note.text.trim())), child: const Text('Activate')),
          ],
        ),
      ),
    );
    note.dispose();
    if (res != null) bloc.add(CrisisActivateRequested(res.$1, res.$2));
  }
}

class _Active extends StatelessWidget {
  const _Active({required this.state, required this.admin, required this.layout, required this.selected, required this.onSelect, this.openUrl});
  final CrisisState state;
  final bool admin;
  final MineLayoutData? layout;
  final String? selected;
  final ValueChanged<String?> onSelect;
  final Future<void> Function(Uri)? openUrl;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CrisisBloc>();
    final c = MgColors.of(context);
    final crisis = state.crisis!;
    final elapsed = crisis.startedAt == null ? Duration.zero : DateTime.now().toUtc().difference(crisis.startedAt!);
    final mm = elapsed.inMinutes.toString().padLeft(2, '0'), ss = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final selRoutes = state.routes.where((r) => r.workerId == selected).toList();
    final selName = selected == null ? null : (state.roster.where((r) => r.userId == selected).map((r) => r.name).firstOrNull ?? state.positions[selected]?.name);
    final statuses = {for (final r in state.roster) r.userId: r.status};
    final blocked = crisis.blockedEdgeIds.toSet();

    final header = Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(color: c.crisis, borderRadius: BorderRadius.circular(Radii.card)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.crisis_alert, color: Colors.white, size: 28),
          const SizedBox(width: Space.sm),
          const Expanded(child: Text('CRISIS ACTIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))),
          Text('$mm:$ss', key: const ValueKey('crisis-timer'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
        if (crisis.reason.isNotEmpty) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text(crisis.reason, style: const TextStyle(color: Colors.white))),
        if (crisis.startedAt != null) Text('Started ${formatIstTime(crisis.startedAt!)}', style: const TextStyle(color: Colors.white70)),
      ]),
    );

    final map = CrisisMap(
      layout: layout,
      positions: state.positions.values.toList(),
      statuses: statuses,
      routes: state.routes,
      blocked: blocked,
      zoneCodes: crisis.zoneCodes.toSet(),
      selected: selected,
      onWorker: onSelect,
      onTunnel: admin ? (id) => bloc.add(CrisisEdgeToggled(id, !blocked.contains(id))) : null,
      height: 340,
    );

    final actions = Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
      if (admin) ...[
        MgButton(label: 'Resolve crisis', icon: Icons.task_alt, loading: state.busy, onPressed: () async {
          final r = await showResolveDialog(context, everyoneAccounted: state.allAccounted);
          if (r != null) bloc.add(CrisisResolveRequested(falseAlarm: r.falseAlarm, note: r.note, allAccounted: r.allAccounted, hazardsContained: r.hazardsContained));
        }),
        MgButton(label: 'Recompute routes', kind: MgButtonKind.secondary, icon: Icons.alt_route, onPressed: () => bloc.add(const CrisisRecomputeRequested())),
        if (crisis.shareToken != null)
          MgButton(label: 'Copy public link', kind: MgButtonKind.secondary, icon: Icons.link, onPressed: () async {
            await Clipboard.setData(ClipboardData(text: '$apiBaseUrl/public/track/${crisis.shareToken}'));
            if (context.mounted) Toast.show(context, 'Public tracking link copied');
          }),
      ],
    ]);

    final left = [
      map,
      if (admin) Padding(padding: const EdgeInsets.only(top: Space.xs), child: Text('Tap a tunnel to block or reopen it. Routes update at once.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted))),
      const SizedBox(height: Space.md),
      RoutePanel(workerName: selName, routes: selRoutes, onAssign: admin && selected != null ? (r) => bloc.add(CrisisRouteAssignRequested(selected!, r.exitId)) : null),
    ];
    final right = [
      RosterPanel(roster: state.roster, counts: state.counts, positions: state.positions, selected: selected, onSelect: onSelect, onStatus: (id, s) => bloc.add(CrisisAccountedSet(id, s))),
      const SizedBox(height: Space.md),
      TimelinePanel(lines: crisis.timeline),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Space.lg),
      child: ContentWidth(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          header,
          const SizedBox(height: Space.md),
          TriggerChips(triggers: crisis.triggers, zoneCodes: crisis.zoneCodes),
          const SizedBox(height: Space.md),
          actions,
          const SizedBox(height: Space.lg),
          LayoutBuilder(builder: (context, box) {
            if (box.maxWidth >= 900) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: Column(children: left)), const SizedBox(width: Space.lg), Expanded(flex: 4, child: Column(children: right))]);
            }
            return Column(children: [...left, const SizedBox(height: Space.md), ...right]);
          }),
        ]),
      ),
    );
  }
}

class _Resolved extends StatelessWidget {
  const _Resolved({required this.state, required this.admin, this.openUrl});
  final CrisisState state;
  final bool admin;
  final Future<void> Function(Uri)? openUrl;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final counts = state.counts;
    final started = state.crisis?.startedAt, ended = state.resolvedAt;
    final mins = started != null && ended != null ? ended.difference(started).inMinutes : null;
    final url = state.report?['url'] as String?;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.lg),
        child: ContentWidth(
          maxWidth: 560,
          child: MgCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Icon(Icons.check_circle, color: c.success, size: 32), const SizedBox(width: Space.sm), Expanded(child: Text(state.falseAlarm ? 'False alarm closed' : 'Crisis resolved', style: t.titleLarge))]),
              const SizedBox(height: Space.md),
              if (mins != null) Text('Duration: $mins min', style: t.bodyMedium),
              Text('Safe ${counts[AccountedStatus.safe]} · Missing ${counts[AccountedStatus.missing]} · Injured ${counts[AccountedStatus.injured]} · Unknown ${counts[AccountedStatus.unknown]}', style: t.bodyMedium),
              const SizedBox(height: Space.lg),
              if (admin) ...[
                MgButton(
                  label: url == null ? 'Load post-crisis report' : 'Open PDF report',
                  icon: Icons.picture_as_pdf,
                  kind: MgButtonKind.secondary,
                  onPressed: () async {
                    if (url == null) {
                      context.read<CrisisBloc>().add(const CrisisReportRequested());
                    } else {
                      await (openUrl ?? (u) async { await launchUrl(u, mode: LaunchMode.externalApplication); })(Uri.parse(url));
                    }
                  },
                ),
                const SizedBox(height: Space.sm),
              ],
              MgButton(
                label: admin ? 'Back to overview' : 'Back to my feed',
                onPressed: () {
                  context.read<CrisisBloc>().add(const CrisisCleared());
                  context.go(admin ? Routes.admin : Routes.supervisor);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

