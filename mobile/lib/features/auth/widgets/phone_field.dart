import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_text_field.dart';
import '../data/countries.dart';
import '../data/phone_validator.dart';

/// Digits only, max 15 (India 10), no counter / suggestions / autofill. Errors are supplied by the parent
/// (shown after blur or submit). A valid number shows a green check and its formatted form.
class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller, required this.focusNode, required this.country, required this.errorText, required this.showValid, this.onChanged, this.onSubmitted, this.label = 'Mobile number'});
  final TextEditingController controller;
  final FocusNode focusNode;
  final Country? country;
  final String? errorText;
  final bool showValid;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final v = validatePhone(country?.isoCode, controller.text);
    final maxLen = country?.isoCode == 'IN' ? 10 : 15;
    return MgTextField(
      controller: controller,
      focusNode: focusNode,
      label: label,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      maxLength: maxLen,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(maxLen)],
      errorText: errorText,
      helperText: showValid && v.isValid ? v.formatted : null,
      suffix: showValid && v.isValid ? Icon(Icons.check_circle, color: c.success) : null,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
