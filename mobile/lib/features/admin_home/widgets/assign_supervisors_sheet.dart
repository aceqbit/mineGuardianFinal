import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../data/admin_repository.dart';

/// Switches for every supervisor; returns the chosen ids. A supervisor supervises one zone, so enabling one here moves them.
Future<List<String>?> showAssignSupervisorsSheet(BuildContext context, {required ZoneOverview zone, required List<SupervisorRef> all}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Sheet(zone: zone, all: all),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.zone, required this.all});
  final ZoneOverview zone;
  final List<SupervisorRef> all;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  late final Set<String> _sel = widget.zone.supervisors.map((s) => s.id).toSet();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = MgColors.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Supervisors · ${widget.zone.code}', style: t.headlineSmall),
            const SizedBox(height: Space.xs),
            Text('Switch on the supervisors who should oversee this zone.', style: t.bodySmall),
            const SizedBox(height: Space.md),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                for (final s in widget.all)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _sel.contains(s.id),
                    title: Text(s.fullName),
                    subtitle: Text(s.phoneMasked, style: t.bodySmall?.copyWith(color: c.muted)),
                    onChanged: (v) => setState(() => v ? _sel.add(s.id) : _sel.remove(s.id)),
                  ),
              ]),
            ),
            const SizedBox(height: Space.md),
            MgButton(label: 'Save', expand: true, onPressed: () => Navigator.of(context).pop(_sel.toList())),
          ]),
        ),
      ),
    );
  }
}
