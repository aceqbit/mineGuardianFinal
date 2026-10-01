import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/ui/mg_text_field.dart';

/// Read-only field that opens a date picker. Starts empty; owns its controller.
class DateField extends StatefulWidget {
  const DateField({super.key, required this.label, required this.value, required this.firstDate, required this.lastDate, required this.onChanged, this.errorText, this.initialPickerDate});
  final String label;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onChanged;
  final String? errorText;
  final DateTime? initialPickerDate;

  @override
  State<DateField> createState() => _DateFieldState();
}

class _DateFieldState extends State<DateField> {
  late final TextEditingController _c = TextEditingController(text: _fmt(widget.value));

  static String _fmt(DateTime? d) => d == null ? '' : DateFormat('d MMM yyyy').format(d);

  @override
  void didUpdateWidget(covariant DateField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _c.text = _fmt(widget.value);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final init = widget.value ?? widget.initialPickerDate ?? widget.lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: init.isBefore(widget.firstDate) ? widget.firstDate : (init.isAfter(widget.lastDate) ? widget.lastDate : init),
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => MgTextField(
        controller: _c,
        label: widget.label,
        readOnly: true,
        onTap: _pick,
        errorText: widget.errorText,
        suffix: const Icon(Icons.calendar_today, size: 20),
      );
}
