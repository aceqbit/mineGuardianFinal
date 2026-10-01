import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/ui/app_scaffold.dart';
import '../../../app/ui/connection_banner.dart';
import '../../../contracts/routes.dart';
import '../../../core/auth/session_bloc.dart';
import '../../../core/socket/socket_service.dart';

/// Badge counters shared by every admin screen's navigation (kept outside any single screen's bloc).
class AdminBadges {
  AdminBadges._();
  static final ValueNotifier<int> sla = ValueNotifier<int>(0);
}

enum AdminSection { overview, normal, crisis, broadcast, contacts, reports, leaderboard }

const _routes = {
  AdminSection.overview: Routes.admin,
  AdminSection.normal: Routes.adminNormal,
  AdminSection.crisis: Routes.adminCrisis,
  AdminSection.broadcast: Routes.adminBroadcast,
  AdminSection.contacts: Routes.adminContacts,
  AdminSection.reports: Routes.adminReports,
  AdminSection.leaderboard: Routes.leaderboard,
};

List<NavDest> adminDestinations({int slaBadge = 0}) => [
      const NavDest(label: 'Overview', icon: Icons.dashboard),
      NavDest(label: 'Normal Mode', icon: Icons.fact_check, badge: slaBadge),
      const NavDest(label: 'Crisis', icon: Icons.crisis_alert),
      const NavDest(label: 'Broadcast', icon: Icons.campaign),
      const NavDest(label: 'Contacts', icon: Icons.contact_phone),
      const NavDest(label: 'Reports', icon: Icons.assessment),
      const NavDest(label: 'Leaderboard', icon: Icons.leaderboard),
    ];

/// Shared admin shell: permanent ink900 side nav on expanded, bottom/rail navigation elsewhere.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.section, required this.title, required this.body, this.actions = const [], this.floatingActionButton});
  final AdminSection section;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final socket = context.read<SocketService>();
    return ValueListenableBuilder<int>(
      valueListenable: AdminBadges.sla,
      builder: (context, sla, _) => AppScaffold(
        title: title,
        selectedIndex: section.index,
        destinations: adminDestinations(slaBadge: sla),
        onSelect: (i) {
          final target = AdminSection.values[i];
          if (target == AdminSection.normal) AdminBadges.sla.value = 0;
          if (target != section) context.go(_routes[target]!);
        },
        banner: ConnectionBanner(connected: socket.connection$),
        actions: [...actions, IconButton(tooltip: 'Log out', icon: const Icon(Icons.logout), onPressed: () => context.read<SessionBloc>().add(const LoggedOut()))],
        floatingActionButton: floatingActionButton,
        body: body,
      ),
    );
  }
}
