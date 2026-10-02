import 'package:go_router/go_router.dart';

import '../contracts/routes.dart';
import '../features/admin_normal/view/admin_normal_screen.dart';
import '../features/admin_normal/view/reports_screen.dart';
import '../features/broadcast/view/broadcast_screen.dart';
import '../features/compliance_review/view/review_screen.dart';
import '../features/contacts/view/contacts_screen.dart';
import '../features/crisis/view/crisis_console_screen.dart';
import '../features/leaderboard/view/leaderboard_screen.dart';
import '../features/rewards/view/rewards_screen.dart';

/// Phase 2 routes.
List<RouteBase> phase2Routes() => [
      GoRoute(path: Routes.supervisorReview, builder: (c, s) => ReviewScreen(checkInId: s.pathParameters['checkInId']!)),
      GoRoute(path: Routes.leaderboard, builder: (c, s) => const LeaderboardScreen()),
      GoRoute(path: Routes.rewards, builder: (c, s) => const RewardsScreen()),
      GoRoute(path: Routes.adminNormal, builder: (c, s) => const AdminNormalScreen()),
      GoRoute(path: Routes.adminReports, builder: (c, s) => const ReportsScreen()),
      GoRoute(path: Routes.adminCrisis, builder: (c, s) => const CrisisConsoleScreen(admin: true)),
      GoRoute(path: Routes.adminBroadcast, builder: (c, s) => const BroadcastScreen()),
      GoRoute(path: Routes.adminContacts, builder: (c, s) => const ContactsScreen()),
      GoRoute(path: Routes.crisisView, builder: (c, s) => const CrisisConsoleScreen(admin: false)),
    ];
