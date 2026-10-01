import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field that never autofills, suggests or autocorrects.
class MgTextField extends StatelessWidget {
  const MgTextField({
    super.key,
    required this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLength,
    this.maxLines = 1,
    this.suffix,
    this.prefix,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.textCapitalization = TextCapitalization.none,
    this.readOnly = false,
    this.onTap,
    this.enabled = true,
    this.helperText,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;
  final String? errorText;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLength;
  final int maxLines;
  final Widget? suffix;
  final Widget? prefix;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextCapitalization textCapitalization;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: onTap,
      enabled: enabled,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: null,
      enableIMEPersonalizedLearning: false,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        helperText: helperText,
        counterText: '',
        suffixIcon: suffix,
        prefixIcon: prefix,
      ),
    );
  }
}
