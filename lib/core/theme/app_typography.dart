import 'package:flutter/material.dart';

/// Typography tokens shared with the future web design system.
abstract final class AppTypography {
  static const fontFamily = 'Roboto';
  static const fontFamilyFallback = <String>['Arial', 'sans-serif'];

  static TextTheme build(TextTheme base, Color foreground) => base
      .apply(
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        bodyColor: foreground,
        displayColor: foreground,
      )
      .copyWith(
        displaySmall: base.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        headlineSmall: base.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        titleLarge: base.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        bodyLarge: base.bodyLarge?.copyWith(letterSpacing: 0),
        bodyMedium: base.bodyMedium?.copyWith(letterSpacing: 0),
        labelLarge: base.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      );
}
