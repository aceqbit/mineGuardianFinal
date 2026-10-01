import 'package:flutter/material.dart';

import '../../../app/responsive.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/stat_card.dart';
import '../data/admin_repository.dart';

/// Workers, Supervisors, Zones, Today's compliance % ("—" when none), Pending reviews, Open hazards.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.overview});
  final AdminOverview? overview;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final o = overview;
    return AdaptiveGrid(
      fixedTileHeight: 104,
      minTileWidth: 150,
      maxColumns: 6,
      children: [
        StatCard(label: 'Workers', value: o?.workers, icon: Icons.engineering),
        StatCard(label: 'Supervisors', value: o?.supervisors, icon: Icons.badge),
        StatCard(label: 'Zones', value: o?.zoneCount, icon: Icons.map),
        StatCard(label: "Today's compliance", value: o?.compliancePct, suffix: o?.compliancePct == null ? '' : '%', icon: Icons.verified, tone: c.success),
        StatCard(label: 'Pending reviews', value: o?.pendingReviews, icon: Icons.pending_actions, tone: (o?.pendingReviews ?? 0) > 0 ? c.warning : null),
        StatCard(label: 'Open hazards', value: o?.openHazards, icon: Icons.warning_amber, tone: (o?.openHazards ?? 0) > 0 ? c.danger : null),
      ],
    );
  }
}
