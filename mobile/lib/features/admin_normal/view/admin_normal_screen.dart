import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/section_header.dart';
import '../../../app/ui/skeleton.dart';
import '../../../app/ui/stat_card.dart';
import '../../../app/ui/status_chip.dart';
import '../../../app/ui/toast.dart';
import '../../../contracts/socket_events.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/time/ist.dart';
import '../../admin_home/widgets/admin_nav.dart';
import '../data/admin_normal_repository.dart';

class AdminNormalState {
  const AdminNormalState({this.loading = true, this.sla = const SlaOverview(), this.audit = const HazardAudit(), this.error});
  final bool loading;
  final SlaOverview sla;
  final HazardAudit audit;
  final String? error;
}

class AdminNormalCubit extends Cubit<AdminNormalState> {
  AdminNormalCubit(this._repo, SocketService socket) : super(const AdminNormalState()) {
    _sub = socket.on(SocketEvents.slaBreach).listen((_) => load());
  }
  final AdminNormalRepository _repo;
  late final dynamic _sub;

  Future<void> load() async {
    try {
      final r = await Future.wait([_repo.sla(), _repo.hazardAudit()]);
      emit(AdminNormalState(loading: false, sla: r[0] as SlaOverview, audit: r[1] as HazardAudit));
    } on ApiException catch (e) {
      emit(AdminNormalState(loading: false, sla: state.sla, audit: state.audit, error: e.message));
    }
  }

  Future<String?> compensate(String id, bool approve, String note) async {
    try {
      await _repo.compensate(id, approve: approve, note: note);
      await load();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> ack(String id) async {
    try {
      await _repo.ackEscalation(id);
    } on ApiException {
      // the refresh below shows the real state
    }
    await load();
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}

class AdminNormalScreen extends StatelessWidget {
  const AdminNormalScreen({super.key, this.repository});
  final AdminNormalRepository? repository;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (ctx) => AdminNormalCubit(repository ?? AdminNormalRepository(api: ctx.read<ApiClient>()), ctx.read<SocketService>())..load(),
        child: const _View(),
      );
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AdminScaffold(
        section: AdminSection.normal,
        title: 'Normal mode',
        body: Column(children: [
          const TabBar(tabs: [Tab(text: 'Review SLA'), Tab(text: 'Hazard audit')]),
          Expanded(
            child: BlocBuilder<AdminNormalCubit, AdminNormalState>(
              builder: (context, s) {
                if (s.loading) return const Padding(padding: EdgeInsets.all(Space.lg), child: SkeletonList(count: 4));
                if (s.error != null && s.sla.supervisors.isEmpty) return EmptyState(icon: Icons.cloud_off, title: 'Could not load', message: s.error, actionLabel: 'Retry', onAction: () => context.read<AdminNormalCubit>().load());
                return TabBarView(children: [_SlaTab(sla: s.sla), _AuditTab(audit: s.audit)]);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _SlaTab extends StatelessWidget {
  const _SlaTab({required this.sla});
  final SlaOverview sla;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: () => context.read<AdminNormalCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        children: [
          ContentWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('${sla.pending} reviews waiting for a decision.', style: t.bodyMedium?.copyWith(color: c.muted)),
              const SectionHeader(title: 'Supervisor reliability (30 days)'),
              if (sla.supervisors.isEmpty) const EmptyState(icon: Icons.groups, title: 'No supervisors') else for (final s in sla.supervisors) _SupervisorRow(s: s),
              if (sla.escalations.isNotEmpty) ...[
                const SectionHeader(title: 'Escalations'),
                for (final e in sla.escalations)
                  _ReviewRow(r: e, label: 'Close to breach · ${e.remindersSent} reminders sent', action: 'Acknowledge', onAction: () => context.read<AdminNormalCubit>().ack(e.reviewId)),
              ],
              const SectionHeader(title: 'SLA breaches'),
              if (sla.breaches.isEmpty)
                const EmptyState(icon: Icons.verified, title: 'No SLA breaches', message: 'Every review was decided in time.')
              else
                for (final b in sla.breaches)
                  _ReviewRow(
                    r: b,
                    label: b.compensated ? 'Compensated · streak restored' : 'Breached · streak frozen',
                    action: b.compensated ? null : 'Review',
                    onAction: () => _compensateDialog(context, b),
                  ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _compensateDialog(BuildContext context, SlaReview r) async {
    final ctl = TextEditingController();
    final cubit = context.read<AdminNormalCubit>();
    final res = await showDialog<(bool, String)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Compensate this breach?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Approving restores the worker streak and score for the frozen day.'),
            const SizedBox(height: Space.md),
            TextField(controller: ctl, maxLength: 500, onChanged: (_) => set(() {}), decoration: const InputDecoration(labelText: 'Note (min 5 characters)')),
          ]),
          actions: [
            TextButton(onPressed: ctl.text.trim().length < 5 ? null : () => Navigator.pop(ctx, (false, ctl.text.trim())), child: const Text('Deny')),
            FilledButton(onPressed: ctl.text.trim().length < 5 ? null : () => Navigator.pop(ctx, (true, ctl.text.trim())), child: const Text('Approve')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (res == null) return;
    final err = await cubit.compensate(r.reviewId, res.$1, res.$2);
    if (context.mounted) Toast.show(context, err ?? (res.$1 ? 'Compensation approved' : 'Compensation denied'), kind: err == null ? ToastKind.success : ToastKind.error);
  }
}

class _SupervisorRow extends StatelessWidget {
  const _SupervisorRow({required this.s});
  final SupervisorReliability s;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final color = s.noData ? c.muted : (s.reliability >= 85 ? c.success : s.reliability >= 60 ? c.warning : c.danger);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: MgCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.fullName, style: Theme.of(context).textTheme.titleSmall),
              Text('${s.zoneCode} · ${s.decided} decided · ${s.onTime} on time · ${s.breaches} breaches', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
            ]),
          ),
          Text(s.noData ? 'No data' : '${s.reliability}%', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.r, required this.label, required this.onAction, this.action});
  final SlaReview r;
  final String label;
  final String? action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: MgCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${r.workerName} · ${r.zoneCode}', style: Theme.of(context).textTheme.titleSmall),
              Text('$label${r.dueAt == null ? '' : ' · due ${formatIst(r.dueAt!, pattern: 'dd MMM HH:mm')}'}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
            ]),
          ),
          if (action != null) MgButton(label: action!, kind: MgButtonKind.secondary, onPressed: onAction),
        ]),
      ),
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.audit});
  final HazardAudit audit;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return RefreshIndicator(
      onRefresh: () => context.read<AdminNormalCubit>().load(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: Space.lg),
        children: [
          ContentWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AdaptiveGrid(minTileWidth: 150, maxColumns: 4, fixedTileHeight: 96, children: [
                StatCard(label: 'Hazards (7 days)', value: audit.total, icon: Icons.warning_amber),
                StatCard(label: 'Open', value: audit.byStatus['OPEN'] ?? 0, icon: Icons.report_problem),
                StatCard(label: 'Median ack (min)', value: audit.medianAckMinutes, icon: Icons.timer),
                StatCard(label: 'Open > 30 min', value: audit.slowOpen, icon: Icons.hourglass_bottom),
              ]),
              const SectionHeader(title: 'Response timeline'),
              if (audit.hazards.isEmpty)
                const EmptyState(icon: Icons.verified_user, title: 'No hazards reported', message: 'Nothing was reported in the last 7 days.')
              else
                for (final h in audit.hazards)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: MgCard(
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${h.category.replaceAll('_', ' ')} · ${h.zoneCode}', style: Theme.of(context).textTheme.titleSmall),
                            Text('${h.reporter}${h.createdAt == null ? '' : ' · ${formatIst(h.createdAt!, pattern: 'dd MMM HH:mm')}'} · ack ${h.ackMinutes ?? '—'} min · closed ${h.closeMinutes ?? '—'} min', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
                          ]),
                        ),
                        StatusChip(label: h.slow ? '${h.status} · slow' : h.status, tone: h.slow ? ChipTone.danger : (h.status == 'CLOSED' ? ChipTone.success : ChipTone.neutral)),
                      ]),
                    ),
                  ),
            ]),
          ),
        ],
      ),
    );
  }
}
