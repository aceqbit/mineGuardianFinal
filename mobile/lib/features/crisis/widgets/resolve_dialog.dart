import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

class ResolveInput {
  const ResolveInput({required this.falseAlarm, required this.note, required this.allAccounted, required this.hazardsContained});
  final bool falseAlarm, allAccounted, hazardsContained;
  final String note;
}

/// A real crisis can only be closed when everyone is accounted for and hazards are contained; a false alarm needs neither. Note >= 10 characters.
Future<ResolveInput?> showResolveDialog(BuildContext context, {required bool everyoneAccounted}) => showDialog<ResolveInput>(context: context, builder: (_) => _ResolveDialog(everyoneAccounted: everyoneAccounted));

class _ResolveDialog extends StatefulWidget {
  const _ResolveDialog({required this.everyoneAccounted});
  final bool everyoneAccounted;

  @override
  State<_ResolveDialog> createState() => _ResolveDialogState();
}

class _ResolveDialogState extends State<_ResolveDialog> {
  final _note = TextEditingController();
  bool _false = false, _accounted = false, _contained = false;

  @override
  void initState() {
    super.initState();
    _accounted = widget.everyoneAccounted;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _ok => _note.text.trim().length >= 10 && (_false || (_accounted && _contained));

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return AlertDialog(
      title: const Text('Resolve crisis'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('This was a false alarm'), value: _false, onChanged: (v) => setState(() => _false = v)),
          if (!_false) ...[
            CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Everyone is accounted for'), value: _accounted, onChanged: (v) => setState(() => _accounted = v ?? false)),
            CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Hazards are contained'), value: _contained, onChanged: (v) => setState(() => _contained = v ?? false)),
            if (!widget.everyoneAccounted) Text('Some workers are still missing or unknown.', style: TextStyle(color: c.warning)),
          ],
          const SizedBox(height: Space.sm),
          TextField(controller: _note, maxLines: 3, maxLength: 500, onChanged: (_) => setState(() {}), decoration: const InputDecoration(labelText: 'Resolution note', helperText: 'At least 10 characters')),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _ok ? () => Navigator.pop(context, ResolveInput(falseAlarm: _false, note: _note.text.trim(), allAccounted: _accounted, hazardsContained: _contained)) : null, child: const Text('Resolve')),
      ],
    );
  }
}
