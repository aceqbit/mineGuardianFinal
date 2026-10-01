import 'package:flutter/material.dart';

import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';

const signupStepTitles = ['Account', 'Work', 'Personal'];

/// Animated 3-step indicator. [vertical] renders the expanded-layout side rail list.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.step, this.vertical = false, this.onTap});
  final int step;
  final bool vertical;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final items = [for (var i = 0; i < signupStepTitles.length; i++) _item(context, i)];
    if (vertical) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: items);
    return Row(children: [for (var i = 0; i < items.length; i++) ...[if (i > 0) Expanded(child: _line(context, i)), items[i]]]);
  }

  Widget _line(BuildContext context, int i) {
    final c = MgColors.of(context);
    return AnimatedContainer(duration: Motion.of(context, Motion.slow), height: 2, margin: const EdgeInsets.symmetric(horizontal: Space.sm), color: step >= i ? c.amber500 : c.border);
  }

  Widget _item(BuildContext context, int i) {
    final c = MgColors.of(context);
    final t = Theme.of(context).textTheme;
    final done = i < step;
    final active = i == step;
    final dot = AnimatedContainer(
      duration: Motion.of(context, Motion.base),
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? c.success : (active ? c.amber500 : Colors.transparent),
        border: Border.all(color: done ? c.success : (active ? c.amber500 : c.border), width: 2),
      ),
      child: done ? const Icon(Icons.check, size: 18, color: Colors.white) : Text('${i + 1}', style: t.labelLarge?.copyWith(color: active ? c.ink900 : c.muted)),
    );
    final label = Text(signupStepTitles[i], style: t.labelLarge?.copyWith(color: active ? c.text : c.muted));
    final child = vertical
        ? Padding(padding: const EdgeInsets.symmetric(vertical: Space.sm), child: Row(children: [dot, const SizedBox(width: Space.md), label]))
        : Row(mainAxisSize: MainAxisSize.min, children: [dot, const SizedBox(width: Space.sm), if (active || done) label]);
    return Semantics(label: 'Step ${i + 1} of 3, ${signupStepTitles[i]}${active ? ', current' : ''}', excludeSemantics: true, child: InkWell(onTap: done && onTap != null ? () => onTap!(i) : null, child: child));
  }
}
