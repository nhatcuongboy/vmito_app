import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_typography.dart';

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
      error: AppColors.errorDark,
      onError: AppColors.destructiveForegroundDark,
      surface: AppColors.cardDark,
      onSurface: AppColors.cardForegroundDark,
      onSurfaceVariant: AppColors.mutedForegroundDark,
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
    final base = ThemeData(
      brightness: brightness,
      colorScheme: scheme,
      useMaterial3: true,
    );
    final textTheme = AppTypography.build(base.textTheme, scheme.onSurface);
    final buttonLabel = AppTypography.buttonLabel(textTheme);
    final tabLabel = (textTheme.labelLarge ?? const TextStyle()).copyWith(
      height: 20 / 14,
      fontWeight: FontWeight.w600,
    );
    final unselectedTabLabel = tabLabel.copyWith(fontWeight: FontWeight.w500);

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBackground,
      extensions: [palette],
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleSpacing: 8,
        titleTextStyle: AppTypography.appBarTitle(textTheme).copyWith(
          color: scheme.onSurface,
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
          minimumSize: const Size(0, AppSizes.minTapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: buttonLabel,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.minTapTarget),
          side: BorderSide(color: palette.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          textStyle: buttonLabel,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: buttonLabel),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        extendedTextStyle: textTheme.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: WidgetStateColor.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return brightness == Brightness.light
                ? palette.muted.withValues(alpha: 0.7)
                : palette.muted.withValues(alpha: 0.4);
          }
          return brightness == Brightness.light
              ? AppColors.background
              : AppColors.cardDark;
        }),
        // Keep supporting text visually secondary to entered values. Without
        // this, Material 3 falls back to `onSurfaceVariant`, which is darker
        // than the app's muted token in the light theme.
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: palette.mutedForeground,
        ),
        labelStyle: _inputLabelStyle(
          scheme,
          palette,
          textTheme.bodyMedium ?? const TextStyle(),
        ),
        floatingLabelStyle: _inputLabelStyle(
          scheme,
          palette,
          textTheme.bodyMedium ?? const TextStyle(),
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: palette.mutedForeground,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
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
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(
            color: palette.border.withValues(alpha: 0.5),
          ),
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
        labelStyle: textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: tabLabel,
        unselectedLabelStyle: unselectedTabLabel,
        labelColor: scheme.onSurface,
        unselectedLabelColor: palette.mutedForeground,
        indicatorColor: scheme.primary,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: palette.mutedForeground,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: AppSizes.bottomNavHeight,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(
          alpha: brightness == Brightness.light ? 0.16 : 0.20,
        ),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelPadding: const EdgeInsets.only(top: AppSpacing.xxs),
        iconTheme: _navigationIconTheme(scheme, palette),
        labelTextStyle: _navigationLabelStyle(scheme, palette),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.primary;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return scheme.onPrimary;
            }
            return scheme.onSurface;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(color: palette.border),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(tabLabel),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: (textTheme.titleLarge ?? const TextStyle()).copyWith(
          fontSize: 20,
          height: 28 / 20,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }

  static WidgetStateTextStyle _inputLabelStyle(
    ColorScheme scheme,
    AppPalette palette,
    TextStyle baseStyle,
  ) => WidgetStateTextStyle.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return baseStyle.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.38),
      );
    }
    if (states.contains(WidgetState.error)) {
      return baseStyle.copyWith(color: scheme.error);
    }
    if (states.contains(WidgetState.focused)) {
      return baseStyle.copyWith(color: scheme.primary);
    }
    return baseStyle.copyWith(color: palette.mutedForeground);
  });

  static WidgetStateProperty<IconThemeData?> _navigationIconTheme(
    ColorScheme scheme,
    AppPalette palette,
  ) => WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return IconThemeData(
        color: scheme.onSurface.withValues(alpha: 0.38),
        size: 24,
      );
    }
    return IconThemeData(
      color: states.contains(WidgetState.selected)
          ? scheme.primary
          : palette.mutedForeground,
      size: 24,
    );
  });

  static WidgetStateTextStyle _navigationLabelStyle(
    ColorScheme scheme,
    AppPalette palette,
  ) => WidgetStateTextStyle.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return TextStyle(
        color: scheme.onSurface.withValues(alpha: 0.38),
        fontSize: 12,
      );
    }
    final selected = states.contains(WidgetState.selected);
    return TextStyle(
      color: selected ? scheme.primary : palette.mutedForeground,
      fontSize: 12,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );
  });
}
