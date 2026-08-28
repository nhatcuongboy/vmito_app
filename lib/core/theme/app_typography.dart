import 'package:flutter/material.dart';

/// Application typography built on the native platform font.
///
/// The web app uses a system-font stack. Leaving [TextStyle.fontFamily]
/// unset gives Flutter the equivalent behaviour: San Francisco on iOS and
/// Roboto on Android, without shipping a second UI font or synthesising
/// unavailable weights.
abstract final class AppTypography {
  static TextTheme build(TextTheme base, Color foreground) {
    final themed = base.apply(
      bodyColor: foreground,
      displayColor: foreground,
    );

    return themed.copyWith(
      displayLarge: themed.displayLarge?.copyWith(
        fontSize: 57,
        height: 64 / 57,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      displayMedium: themed.displayMedium?.copyWith(
        fontSize: 45,
        height: 52 / 45,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      displaySmall: themed.displaySmall?.copyWith(
        fontSize: 36,
        height: 44 / 36,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineLarge: themed.headlineLarge?.copyWith(
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineMedium: themed.headlineMedium?.copyWith(
        fontSize: 28,
        height: 36 / 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineSmall: themed.headlineSmall?.copyWith(
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleLarge: themed.titleLarge?.copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleMedium: themed.titleMedium?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: themed.titleSmall?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: themed.bodyLarge?.copyWith(
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodyMedium: themed.bodyMedium?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      bodySmall: themed.bodySmall?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
      ),
      labelLarge: themed.labelLarge?.copyWith(
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: themed.labelMedium?.copyWith(
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: themed.labelSmall?.copyWith(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }

  /// Page title for a regular [AppBar], kept compact beside navigation icons.
  static TextStyle appBarTitle(TextTheme textTheme) =>
      (textTheme.headlineSmall ?? const TextStyle()).copyWith(
        fontSize: 22,
        height: 28 / 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      );

  /// Space-efficient title for a pinned detail header.
  static TextStyle compactAppBarTitle(TextTheme textTheme) =>
      (textTheme.titleLarge ?? const TextStyle()).copyWith(
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      );

  /// Two-row management header title, tuned for a 72 dp toolbar.
  static TextStyle managementAppBarTitle(TextTheme textTheme) =>
      compactAppBarTitle(textTheme).copyWith(height: 24 / 20);

  /// Primary action text shared by filled, outlined, and text buttons.
  static TextStyle buttonLabel(TextTheme textTheme) =>
      (textTheme.labelLarge ?? const TextStyle()).copyWith(
        fontSize: 15,
        height: 20 / 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      );
}
