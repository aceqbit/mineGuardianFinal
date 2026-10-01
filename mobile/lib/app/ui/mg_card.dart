import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

class MgCard extends StatefulWidget {
  const MgCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Space.lg), this.tone, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? tone;
  final String? semanticLabel;

  @override
  State<MgCard> createState() => _MgCardState();
}

class _MgCardState extends State<MgCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final lift = _hover && widget.onTap != null && !Motion.reduce(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.base),
        transform: Matrix4.translationValues(0, lift ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.tone ?? c.surface,
          borderRadius: BorderRadius.circular(Radii.card),
          border: Border.all(color: c.border),
          boxShadow: Shadows.level(lift ? 2 : 1, dark: dark),
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(Radii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.card),
            onTap: widget.onTap,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
