import 'package:flutter/material.dart';

import '../../../app/responsive.dart';
import '../../../app/ui/mg_segmented.dart';
import '../../../contracts/enums.dart';

class RoleSwitcher extends StatelessWidget {
  const RoleSwitcher({super.key, required this.role, required this.onChanged});
  final Role role;
  final ValueChanged<Role> onChanged;

  @override
  Widget build(BuildContext context) {
    return MgSegmented<Role>(
      value: role,
      onChanged: onChanged,
      stacked: context.isCompact,
      segments: const [
        MgSegment(value: Role.miner, label: 'Miner Login', icon: Icons.engineering),
        MgSegment(value: Role.supervisor, label: 'Supervisor Login', icon: Icons.badge),
        MgSegment(value: Role.admin, label: 'Admin Login', icon: Icons.admin_panel_settings),
      ],
    );
  }
}
