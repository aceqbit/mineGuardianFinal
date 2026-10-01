import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/motion.dart';

/// Shared-axis X for pushes.
CustomTransitionPage<T> sharedAxisPage<T>({required LocalKey key, required Widget child}) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: Motion.slow,
      transitionsBuilder: (context, animation, secondary, child) {
        if (Motion.reduce(context)) return child;
        return SharedAxisTransition(animation: animation, secondaryAnimation: secondary, transitionType: SharedAxisTransitionType.horizontal, child: child);
      },
    );

/// Fade-through for tab / role-home switches.
CustomTransitionPage<T> fadeThroughPage<T>({required LocalKey key, required Widget child}) => CustomTransitionPage<T>(
      key: key,
      child: child,
      transitionDuration: Motion.slow,
      transitionsBuilder: (context, animation, secondary, child) {
        if (Motion.reduce(context)) return child;
        return FadeThroughTransition(animation: animation, secondaryAnimation: secondary, child: child);
      },
    );

extension PageHelpers on GoRouterState {
  LocalKey get pageKeyOrDefault => pageKey;
}
