import 'package:flutter/material.dart';

/// Wraps every page via a ShellRoute. Pass-through until P2.10 / P2.11 add crisis and broadcast banners.
class GlobalOverlays extends StatelessWidget {
  const GlobalOverlays({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
