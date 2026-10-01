import 'package:flutter/material.dart';

/// Styled dropdown; starts with no selection.
class DropdownField<T> extends StatelessWidget {
  const DropdownField({super.key, required this.label, required this.value, required this.items, required this.onChanged, this.itemLabel, this.errorText, this.enabled = true});
  final String label;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T)? itemLabel;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      items: [for (final i in items) DropdownMenuItem<T>(value: i, child: Text(itemLabel?.call(i) ?? '$i', overflow: TextOverflow.ellipsis))],
      onChanged: enabled ? onChanged : null,
    );
  }
}
