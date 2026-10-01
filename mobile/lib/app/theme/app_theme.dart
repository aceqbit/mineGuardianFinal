import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

class AppTheme {
  AppTheme._();

  static const _tabular = [FontFeature.tabularFigures()];

  static TextTheme _text(MgColors c) {
    final base = Typography.material2021().black;
    TextStyle s(double size, double h, FontWeight w, {double ls = 0, Color? color}) =>
        GoogleFonts.inter(fontSize: size, height: h / size, fontWeight: w, letterSpacing: ls, color: color ?? c.text, fontFeatures: _tabular);
    return base.copyWith(
      displayLarge: s(32, 40, FontWeight.w700),
      headlineMedium: s(24, 32, FontWeight.w700),
      headlineSmall: s(20, 28, FontWeight.w600),
      titleMedium: s(16, 24, FontWeight.w600),
      bodyLarge: s(14, 22, FontWeight.w400),
      bodyMedium: s(14, 22, FontWeight.w400),
      bodySmall: s(12, 18, FontWeight.w400, color: c.muted),
      labelLarge: s(12, 16, FontWeight.w600, ls: 0.4),
      labelMedium: s(12, 16, FontWeight.w600, ls: 0.4),
      labelSmall: s(11, 14, FontWeight.w600, ls: 0.4, color: c.muted),
    );
  }

  static ThemeData _build(MgColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.amber500,
      onPrimary: c.ink900,
      secondary: c.ink700,
      onSecondary: Colors.white,
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      surfaceContainerHighest: b == Brightness.light ? c.slate100 : c.surfaceRaised,
      outline: c.border,
    );
    final t = _text(c);
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      textTheme: t,
      extensions: [c],
      dividerColor: c.border,
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: t.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.card), side: BorderSide(color: c.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.amber500, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.sm), borderSide: BorderSide(color: c.danger, width: 2)),
        labelStyle: t.bodyMedium?.copyWith(color: c.muted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      ),
      dialogTheme: DialogThemeData(backgroundColor: c.surface, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sheet))),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData light() => _build(MgColors.light, Brightness.light);
  static ThemeData dark() => _build(MgColors.dark, Brightness.dark);
}
