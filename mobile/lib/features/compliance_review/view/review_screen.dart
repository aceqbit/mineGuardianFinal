import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/skeleton.dart';
import '../../../app/ui/status_chip.dart';
import '../../../app/ui/toast.dart';
import '../../../core/api/api_client.dart';
import '../../../core/socket/socket_service.dart';
import '../../../core/time/ist.dart';
import '../bloc/review_bloc.dart';
import '../bloc/review_event.dart';
import '../bloc/review_state.dart';
import '../data/review_repository.dart';
import '../widgets/checklist_panel.dart';
import '../widgets/decision_bar.dart';
import '../widgets/photo_panel.dart';
import '../widgets/report_sections.dart';
import '../widgets/verdict_panel.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key, required this.checkInId, this.repository, this.openUrl});
  final String checkInId;
  final ReviewRepository? repository;
  final Future<void> Function(Uri)? openUrl;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? ReviewRepository(api: context.read<ApiClient>());
    return BlocProvider(
      create: (ctx) => ReviewBloc(repo: repo, socket: ctx.read<SocketService>(), checkInId: checkInId)..add(const ReviewLoaded()),
      child: _ReviewView(repo: repo, openUrl: openUrl ?? (u) async { await launchUrl(u, mode: LaunchMode.externalApplication); }),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.repo, required this.openUrl});
  final ReviewRepository repo;
  final Future<void> Function(Uri) openUrl;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ReviewBloc, ReviewState>(
      listenWhen: (a, b) => a.message != b.message || a.error != b.error,
      listener: (context, s) {
        if (s.message != null) {
          Toast.show(context, s.message!, kind: ToastKind.success);
          context.read<ReviewBloc>().add(const ReviewNoticeShown());
          if (s.done && context.canPop()) context.pop();
        } else if (s.error != null && s.status == ReviewStatus.ready) {
          Toast.show(context, s.error!, kind: ToastKind.error);
          context.read<ReviewBloc>().add(const ReviewNoticeShown());
        }
      },
      builder: (context, s) {
        final d = s.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(d == null ? 'Compliance review' : '${d.workerName} · ${d.zoneCode}'),
            actions: [
              if (d != null)
                IconButton(
                  tooltip: 'Download PDF report',
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () async {
                    try {
                      await openUrl(Uri.parse(await repo.reportUrl(d.reviewId)));
                    } on ApiException catch (e) {
                      if (context.mounted) Toast.show(context, e.message, kind: ToastKind.error);
                    }
                  },
                ),
            ],
          ),
          body: switch (s.status) {
            ReviewStatus.loading => const Padding(padding: EdgeInsets.all(Space.lg), child: Skeleton(height: 300)),
            ReviewStatus.notFound => const EmptyState(icon: Icons.search_off, title: 'No review yet', message: 'The AI result is not ready for this check-in.'),
            ReviewStatus.failure => EmptyState(icon: Icons.error_outline, title: 'Could not load', message: s.error ?? 'Try again', actionLabel: 'Retry', onAction: () => context.read<ReviewBloc>().add(const ReviewLoaded())),
            ReviewStatus.ready => _Body(state: s),
          },
          bottomNavigationBar: s.status == ReviewStatus.ready && !s.locked
              ? DecisionBar(state: s, onDecide: (a, {level, note}) => context.read<ReviewBloc>().add(DecisionSubmitted(a, level: level, note: note)))
              : null,
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});
  final ReviewState state;

  @override
  Widget build(BuildContext context) {
    final d = state.data!;
    final c = MgColors.of(context);
    final bloc = context.read<ReviewBloc>();
    final photo = PhotoPanel(url: d.facts.imageUrl, aspect: d.facts.imageAspect, items: d.ai.items, yolo: d.ai.yolo);
    final checklist = ChecklistPanel(
      items: state.required,
      selected: state.selected,
      onSelect: (k, v) => bloc.add(ItemSelected(k, v)),
      readOnly: state.locked,
      decidedCount: state.decidedCount,
    );
    final left = [photo, const SizedBox(height: Space.md), TimestampsPanel(facts: d.facts, recent: d.recent)];
    final right = [
      if (state.lockedBy != null) _Banner(text: state.lockedBy!, tone: ChipTone.warning),
      if (d.decision != null)
        _Banner(
          text: '${d.decision!.action.name} · ${d.decision!.finalVerdict.label}${d.decision!.decidedAt == null ? '' : ' · ${formatIst(d.decision!.decidedAt!, pattern: 'dd MMM HH:mm')}'}${d.decision!.note.isEmpty ? '' : '\n${d.decision!.note}'}',
          tone: d.decision!.finalVerdict == d.ai.verdict ? ChipTone.success : ChipTone.info,
        ),
      VerdictPanel(ai: d.ai),
      const SizedBox(height: Space.md),
      checklist,
      const SizedBox(height: Space.md),
      ReportSections(ai: d.ai),
      const SizedBox(height: Space.x3),
    ];
    return RefreshIndicator(
      color: c.amber500,
      onRefresh: () async => bloc.add(const ReviewLoaded()),
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 768;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(Space.lg),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Widths.page),
              child: wide
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 4, child: Column(children: left)),
                      const SizedBox(width: Space.lg),
                      Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: right)),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [...right.take(right.length - 1), const SizedBox(height: Space.md), ...left, const SizedBox(height: Space.x3)]),
            ),
          ),
        );
      }),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.tone});
  final String text;
  final ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final (fg, bg) = switch (tone) { ChipTone.success => (c.success, c.successBg), ChipTone.warning => (c.warning, c.warningBg), _ => (c.info, c.infoBg) };
    return Container(
      margin: const EdgeInsets.only(bottom: Space.md),
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.sm)),
      child: Row(children: [Icon(Icons.lock, size: 18, color: fg), const SizedBox(width: Space.sm), Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600)))]),
    );
  }
}
