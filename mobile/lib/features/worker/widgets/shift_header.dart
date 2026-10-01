import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/pulse_dot.dart';
import '../../../app/ui/status_chip.dart';
import '../../../core/models/session_user.dart';
import '../../../core/time/ist.dart';

class ShiftHeader extends StatelessWidget {
  const ShiftHeader({super.key, required this.user, required this.connected});
  final SessionUser user;
  final Stream<bool> connected;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final shift = user.shift;
    final open = shift != null && isShiftOpen(shift, nowIst());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Hi ${user.firstName}', style: t.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
        StreamBuilder<bool>(
          stream: connected,
          initialData: false,
          builder: (context, snap) => Tooltip(message: snap.data == true ? 'Live' : 'Offline', child: PulseDot(color: snap.data == true ? c.success : c.slate400, pulsing: snap.data == true)),
        ),
      ]),
      const SizedBox(height: Space.xs),
      Text([if (user.zoneCode != null) '${user.zoneCode} · ${user.zoneName ?? ''}'].join(), style: t.bodyMedium?.copyWith(color: c.muted)),
      const SizedBox(height: Space.sm),
      Wrap(spacing: Space.sm, runSpacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (shift != null) Text('Shift ${shift.wire} · ${shift.window}', style: t.labelLarge),
        StatusChip(label: open ? 'Shift open' : 'Shift closed', tone: open ? ChipTone.success : ChipTone.neutral),
      ]),
    ]);
  }
}
