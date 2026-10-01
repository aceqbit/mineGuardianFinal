import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/mg_text_field.dart';
import '../data/password_rules.dart';

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.focusNode, this.label = 'Password', this.errorText, this.showRules = true, this.onSubmitted, this.onChanged, this.textInputAction = TextInputAction.done});
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String? errorText;
  final bool showRules;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules.evaluate(widget.controller.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      MgTextField(
        controller: widget.controller,
        focusNode: widget.focusNode,
        label: widget.label,
        obscureText: _obscure,
        maxLength: 6,
        inputFormatters: [LengthLimitingTextInputFormatter(6), FilteringTextInputFormatter.deny(RegExp(r'\s'))],
        textInputAction: widget.textInputAction,
        errorText: widget.errorText,
        onChanged: (v) {
          setState(() {});
          widget.onChanged?.call(v);
        },
        onSubmitted: widget.onSubmitted,
        suffix: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      if (widget.showRules) ...[
        const SizedBox(height: Space.sm),
        Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
          _RuleChip(label: '6 characters', ok: rules.length),
          _RuleChip(label: 'A letter', ok: rules.hasLetter),
          _RuleChip(label: 'A digit', ok: rules.hasDigit),
          _RuleChip(label: 'No spaces', ok: rules.noSpaces),
        ]),
      ],
    ]);
  }
}

/// A live indicator, not a checkbox.
class _RuleChip extends StatelessWidget {
  const _RuleChip({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final fg = ok ? c.success : c.muted;
    return AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.xs + 1),
      decoration: BoxDecoration(color: ok ? c.successBg : c.slate100.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.08 : 1), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, size: 14, color: fg),
        const SizedBox(width: Space.xs),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
      ]),
    );
  }
}
