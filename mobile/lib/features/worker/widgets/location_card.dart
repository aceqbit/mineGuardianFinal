import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_card.dart';
import '../bloc/hazard_report_state.dart';

class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.state, required this.onRefresh});
  final HazardReportState state;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final fix = state.fix;
    Widget body;
    if (state.locationStatus == LocationStatus.loading) {
      body = Row(children: [const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)), const SizedBox(width: Space.md), Expanded(child: Text('Getting your location…', style: t.bodyMedium))]);
    } else if (state.locationStatus == LocationStatus.unavailable || fix == null) {
      body = Container(
        padding: const EdgeInsets.all(Space.md),
        decoration: BoxDecoration(color: c.warningBg, borderRadius: BorderRadius.circular(Radii.sm)),
        child: Row(children: [
          Icon(Icons.location_off, color: c.warning),
          const SizedBox(width: Space.sm),
          Expanded(child: Text('Location unavailable — report will be sent without GPS', style: t.bodyMedium?.copyWith(color: c.warning))),
        ]),
      );
    } else {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.my_location, size: 18, color: c.info),
          const SizedBox(width: Space.sm),
          Expanded(child: Text('${fix.lat.toStringAsFixed(5)}, ${fix.lng.toStringAsFixed(5)}', style: t.titleMedium)),
        ]),
        const SizedBox(height: Space.xs),
        Text('Accuracy ±${fix.accuracyM.round()} m${fix.isFallback ? ' · last known position' : ''}', style: t.bodySmall),
        const SizedBox(height: Space.xs),
        Text(state.zoneCode == null ? 'Zone: not detected (your own zone will be used)' : 'Zone: ${state.zoneCode}', style: t.bodyMedium?.copyWith(color: state.zoneCode == null ? c.muted : c.success)),
      ]);
    }
    return MgCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        body,
        const SizedBox(height: Space.md),
        Align(alignment: Alignment.centerLeft, child: MgButton(label: 'Refresh location', kind: MgButtonKind.secondary, icon: Icons.refresh, onPressed: state.locationStatus == LocationStatus.loading ? null : onRefresh)),
      ]),
    );
  }
}
