import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/empty_state.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../../../app/ui/skeleton.dart';
import '../../../app/ui/toast.dart';
import '../../../core/api/api_client.dart';
import '../../admin_home/widgets/admin_nav.dart';
import '../data/admin_normal_repository.dart';

class ReportsState {
  const ReportsState({this.loading = true, this.reports = const [], this.busy = false, this.error});
  final bool loading, busy;
  final List<ReportRow> reports;
  final String? error;
}

class ReportsCubit extends Cubit<ReportsState> {
  ReportsCubit(this._repo) : super(const ReportsState());
  final AdminNormalRepository _repo;

  Future<void> load() async {
    try {
      emit(ReportsState(loading: false, reports: await _repo.reports()));
    } on ApiException catch (e) {
      emit(ReportsState(loading: false, reports: state.reports, error: e.message));
    }
  }

  Future<String?> generate() async {
    emit(ReportsState(loading: false, reports: state.reports, busy: true));
    try {
      await _repo.generateReport();
      await load();
      return null;
    } on ApiException catch (e) {
      emit(ReportsState(loading: false, reports: state.reports));
      return e.message;
    }
  }

  Future<String?> url(String id) async {
    try {
      return await _repo.reportUrl(id);
    } on ApiException {
      return null;
    }
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key, this.repository, this.openUrl});
  final AdminNormalRepository? repository;
  final Future<void> Function(Uri)? openUrl;

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (ctx) => ReportsCubit(repository ?? AdminNormalRepository(api: ctx.read<ApiClient>()))..load(),
        child: AdminScaffold(
          section: AdminSection.reports,
          title: 'Reports',
          body: BlocBuilder<ReportsCubit, ReportsState>(
            builder: (context, s) {
              if (s.loading) return const Padding(padding: EdgeInsets.all(Space.lg), child: SkeletonList(count: 4));
              final c = MgColors.of(context);
              return RefreshIndicator(
                onRefresh: () => context.read<ReportsCubit>().load(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: Space.lg),
                  children: [
                    ContentWidth(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: MgButton(
                            label: 'Generate today\'s report',
                            icon: Icons.assessment,
                            loading: s.busy,
                            onPressed: () async {
                              final err = await context.read<ReportsCubit>().generate();
                              if (context.mounted) Toast.show(context, err ?? 'Report generated', kind: err == null ? ToastKind.success : ToastKind.error);
                            },
                          ),
                        ),
                        const SizedBox(height: Space.md),
                        Text('A report is also generated every day at 23:55 IST.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
                        const SizedBox(height: Space.md),
                        if (s.reports.isEmpty)
                          const EmptyState(icon: Icons.assessment, title: 'No reports yet', message: 'Generate one to see the daily safety summary.')
                        else
                          for (final r in s.reports)
                            Padding(
                              padding: const EdgeInsets.only(bottom: Space.sm),
                              child: MgCard(
                                child: Row(children: [
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(r.day, style: Theme.of(context).textTheme.titleSmall),
                                      Text('${r.reviewed} reviewed · ${r.compliancePct == null ? 'no data' : '${r.compliancePct}% compliant'}${r.auto ? ' · automatic' : ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.muted)),
                                    ]),
                                  ),
                                  IconButton(
                                    tooltip: 'Open PDF',
                                    icon: const Icon(Icons.picture_as_pdf),
                                    onPressed: () async {
                                      final u = await context.read<ReportsCubit>().url(r.id);
                                      if (u == null) {
                                        if (context.mounted) Toast.show(context, 'Could not open the report', kind: ToastKind.error);
                                        return;
                                      }
                                      await (openUrl ?? (x) async { await launchUrl(x, mode: LaunchMode.externalApplication); })(Uri.parse(u));
                                    },
                                  ),
                                ]),
                              ),
                            ),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}
