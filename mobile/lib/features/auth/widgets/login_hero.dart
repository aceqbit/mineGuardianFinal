import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/app_images.dart';
import '../../../app/theme/motion.dart';
import '../../../app/theme/tokens.dart';
import '../../../app/ui/skeleton.dart';

/// Hero image with a very slow 1.00 -> 1.06 scale over 20 s (off for reduced motion).
class LoginHero extends StatefulWidget {
  const LoginHero({super.key, this.blurred = false, this.showBrand = true});
  final bool blurred;
  final bool showBrand;

  @override
  State<LoginHero> createState() => _LoginHeroState();
}

class _LoginHeroState extends State<LoginHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduce(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(scale: 1 + 0.06 * _c.value, child: child),
          child: CachedNetworkImage(
            imageUrl: AppImages.loginHero,
            fit: BoxFit.cover,
            placeholder: (_, _) => const Skeleton(radius: 0),
            errorWidget: (_, _, _) => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [c.ink700, c.ink900], begin: Alignment.topLeft, end: Alignment.bottomRight))),
          ),
        ),
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.ink900.withValues(alpha: 0.35), c.ink900.withValues(alpha: 0.85)]))),
        if (widget.showBrand)
          Positioned(
            left: Space.x3,
            right: Space.x3,
            bottom: Space.x3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield, color: c.amber500, size: 40),
              const SizedBox(height: Space.md),
              Text('Mine Guardian', style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: Space.xs),
              Text('Every shift. Every worker. Every exit.', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70)),
            ]),
          ),
      ]),
    );
  }
}
