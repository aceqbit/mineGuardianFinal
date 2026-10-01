import 'package:flutter/material.dart';

import '../../../app/ui/mg_segmented.dart';
import '../bloc/supervisor_feed_event.dart';

class FeedFilters extends StatelessWidget {
  const FeedFilters({super.key, required this.value, required this.onChanged});
  final FeedFilter value;
  final ValueChanged<FeedFilter> onChanged;

  @override
  Widget build(BuildContext context) => MgSegmented<FeedFilter>(
        value: value,
        onChanged: onChanged,
        segments: const [
          MgSegment(value: FeedFilter.all, label: 'All'),
          MgSegment(value: FeedFilter.checkins, label: 'Check-ins'),
          MgSegment(value: FeedFilter.hazards, label: 'Hazards'),
          MgSegment(value: FeedFilter.emergencies, label: 'Emergencies'),
        ],
      );
}
