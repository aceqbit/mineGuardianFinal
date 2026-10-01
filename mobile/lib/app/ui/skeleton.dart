import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = Radii.sm});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(radius)),
    );
    if (Motion.reduce(context)) return box;
    return Shimmer.fromColors(baseColor: c.border, highlightColor: c.surface, child: box);
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3, this.itemHeight = 72});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < count; i++)
            Padding(padding: const EdgeInsets.only(bottom: Space.md), child: Skeleton(height: itemHeight, radius: Radii.card)),
        ],
      );
}
