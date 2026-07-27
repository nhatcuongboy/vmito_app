import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';

/// Light and dark [ThemeData] built from the ported design tokens.
///
/// Colours are pinned explicitly rather than derived from a seed: the web app
/// has fixed tokens, and `ColorScheme.fromSeed` would drift away from them.
abstract final class AppTheme {
  static ThemeData get light => _build(
    brightness: Brightness.light,
    scheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      secondary: AppColors.secondary,
      onSecondary: AppColors.secondaryForeground,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      onSurface: AppColors.cardForeground,
      surfaceContainerHighest: AppColors.muted,
      outline: AppColors.border,
    ),
    scaffoldBackground: AppColors.background,
    palette: AppPalette.light(),
  );

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    scheme: const ColorScheme.dark(
      primary: AppColors.primaryDark,
      onPrimary: AppColors.primaryForegroundDark,
      secondary: AppColors.secondaryDark,
      onSecondary: AppColors.secondaryForegroundDark,
      error: AppColors.destructiveDark,
      onError: AppColors.destructiveForegroundDark,
      surface: AppColors.cardDark,
      onSurface: AppColors.cardForegroundDark,
      surfaceContainerHighest: AppColors.mutedDark,
      outline: AppColors.borderDark,
    ),
    scaffoldBackground: AppColors.backgroundDark,
    palette: AppPalette.dark(),
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffoldBackground,
    required AppPalette palette,
  }) {
    final base = ThemeData(brightness: brightness, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: palette.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.border, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTapTarget),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? AppColors.background
            : AppColors.cardDark,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: palette.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: palette.mutedForeground,
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}
