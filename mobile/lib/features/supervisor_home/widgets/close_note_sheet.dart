import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_button.dart';
import '../../../app/ui/mg_text_field.dart';
import '../../../contracts/enums.dart';

/// Close and Reject need a note (Close >= 5 characters, Reject required). Returns the note or null.
Future<String?> showCloseNoteSheet(BuildContext context, {required HazardStatus action}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NoteSheet(action: action),
  );
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({required this.action});
  final HazardStatus action;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    final min = widget.action == HazardStatus.closed ? 5 : 1;
    if (v.length < min) {
      setState(() => _err = widget.action == HazardStatus.closed ? 'Add a note of at least 5 characters' : 'A note is required to reject');
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final closing = widget.action == HazardStatus.closed;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, MediaQuery.viewInsetsOf(context).bottom + Space.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(closing ? 'Close hazard' : 'Reject hazard', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: Space.sm),
        Text(closing ? 'What was done to make it safe?' : 'Why is this not a hazard?', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: Space.md),
        MgTextField(controller: _c, label: 'Note', maxLines: 3, maxLength: 500, errorText: _err, onChanged: (_) => setState(() => _err = null)),
        const SizedBox(height: Space.md),
        MgButton(label: closing ? 'Close hazard' : 'Reject hazard', kind: closing ? MgButtonKind.primary : MgButtonKind.danger, expand: true, onPressed: _submit),
      ]),
    );
  }
}
