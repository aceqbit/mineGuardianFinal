import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../contracts/enums.dart';
import '../bloc/review_state.dart';

typedef DecisionCallback = void Function(DecisionAction action, {EscalationLevel? level, String? note});

/// Confirm (only when every row matches the AI), Override (rows differ, note required), Escalate (note + level).
class DecisionBar extends StatelessWidget {
  const DecisionBar({super.key, required this.state, required this.onDecide});
  final ReviewState state;
  final DecisionCallback onDecide;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final disabled = state.locked || state.submitting || state.data == null;
    return Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          alignment: WrapAlignment.end,
          children: [
            MgButton(
              label: 'Escalate',
              kind: MgButtonKind.danger,
              icon: Icons.priority_high,
              onPressed: disabled || !state.allDecided ? null : () async {
                final r = await showModalBottomSheet<(EscalationLevel, String)>(context: context, isScrollControlled: true, builder: (_) => const EscalateSheet());
                if (r != null) onDecide(DecisionAction.escalate, level: r.$1, note: r.$2);
              },
            ),
            MgButton(
              label: 'Override',
              kind: MgButtonKind.secondary,
              icon: Icons.edit,
              onPressed: disabled || !state.canOverride ? null : () async {
                final n = await showModalBottomSheet<String>(context: context, isScrollControlled: true, builder: (_) => const NoteSheet(title: 'Override AI result', hint: 'Why does your decision differ from the AI?'));
                if (n != null) onDecide(DecisionAction.overrideAction, note: n);
              },
            ),
            MgButton(
              label: 'Confirm',
              icon: Icons.check,
              loading: state.submitting,
              onPressed: disabled || !state.canConfirm ? null : () => onDecide(DecisionAction.confirm),
            ),
          ],
        ),
      ),
    );
  }
}

class NoteSheet extends StatefulWidget {
  const NoteSheet({super.key, required this.title, required this.hint});
  final String title, hint;

  @override
  State<NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<NoteSheet> {
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctl.text.trim().length >= 10;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, MediaQuery.of(context).viewInsets.bottom + Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.md),
        TextField(controller: _ctl, maxLines: 3, maxLength: 500, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: widget.hint, helperText: 'At least 10 characters')),
        const SizedBox(height: Space.sm),
        MgButton(label: 'Save', expand: true, onPressed: ok ? () => Navigator.pop(context, _ctl.text.trim()) : null),
      ]),
    );
  }
}

class EscalateSheet extends StatefulWidget {
  const EscalateSheet({super.key});

  @override
  State<EscalateSheet> createState() => _EscalateSheetState();
}

class _EscalateSheetState extends State<EscalateSheet> {
  final _ctl = TextEditingController();
  EscalationLevel _level = EscalationLevel.attention;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _ctl.text.trim().length >= 10;
    final emergency = _level == EscalationLevel.emergency;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, MediaQuery.of(context).viewInsets.bottom + Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Escalate to admin', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: Space.md),
        SegmentedButton<EscalationLevel>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: EscalationLevel.attention, label: Text('Needs attention')),
            ButtonSegment(value: EscalationLevel.emergency, label: Text('Emergency')),
          ],
          selected: {_level},
          onSelectionChanged: (s) => setState(() => _level = s.first),
        ),
        if (emergency)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text('This asks the admin to start crisis mode. Nothing is broadcast until the admin signs off.', style: TextStyle(color: MgColors.of(context).danger)),
          ),
        const SizedBox(height: Space.md),
        TextField(controller: _ctl, maxLines: 3, maxLength: 500, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'What did you see?', helperText: 'At least 10 characters')),
        const SizedBox(height: Space.sm),
        MgButton(label: 'Escalate', kind: MgButtonKind.danger, expand: true, onPressed: ok ? () => Navigator.pop(context, (_level, _ctl.text.trim())) : null),
      ]),
    );
  }
}
