import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../contracts/routes.dart';

/// Phase 2 routes. Placeholders until their steps land; each step replaces its own entry.
List<RouteBase> phase2Routes() => [
      GoRoute(path: Routes.supervisorReview, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.leaderboard, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.rewards, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.adminNormal, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.adminReports, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.adminCrisis, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.adminBroadcast, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.adminContacts, builder: (c, s) => const Phase2Placeholder()),
      GoRoute(path: Routes.crisisView, builder: (c, s) => const Phase2Placeholder()),
    ];

class Phase2Placeholder extends StatelessWidget {
  const Phase2Placeholder({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: Text('Coming in Phase 2')));
}
