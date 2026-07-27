import 'package:flutter/material.dart';

/// Design tokens ported 1:1 from `vmito-fe/src/app/globals.css`.
///
/// The web app stores these as HSL CSS custom properties; they are converted
/// to sRGB here. Keep the two in sync — if a token changes on web, change it
/// here, don't eyeball a new colour.
abstract final class AppColors {
  // Brand green. hsl(136 74% 35%) light / hsl(136 74% 45%) dark.
  static const Color brand = Color(0xFF179B3A);
  static const Color brandDark = Color(0xFF1EC84B);

  // --- Light ---------------------------------------------------------------
  static const Color background = Color(0xFFFFFFFF);
  static const Color foreground = Color(0xFF09090B);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardForeground = Color(0xFF09090B);
  static const Color popover = Color(0xFFFFFFFF);
  static const Color popoverForeground = Color(0xFF09090B);
  static const Color primary = Color(0xFF179B3A);
  static const Color primaryForeground = Color(0xFFFFF1F2);
  static const Color secondary = Color(0xFFF4F4F5);
  static const Color secondaryForeground = Color(0xFF18181B);
  static const Color muted = Color(0xFFF4F4F5);
  static const Color mutedForeground = Color(0xFF71717A);
  static const Color accent = Color(0xFFF4F4F5);
  static const Color accentForeground = Color(0xFF18181B);
  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFAFAFA);
  static const Color border = Color(0xFFE4E4E7);
  static const Color input = Color(0xFFE4E4E7);
  static const Color ring = Color(0xFF179B3A);

  // --- Dark ----------------------------------------------------------------
  static const Color backgroundDark = Color(0xFF0C0A09);
  static const Color foregroundDark = Color(0xFFF2F2F2);
  static const Color cardDark = Color(0xFF1C1917);
  static const Color cardForegroundDark = Color(0xFFF2F2F2);
  static const Color popoverDark = Color(0xFF171717);
  static const Color popoverForegroundDark = Color(0xFFF2F2F2);
  static const Color primaryDark = Color(0xFF1EC84B);
  static const Color primaryForegroundDark = Color(0xFF052E16);
  static const Color secondaryDark = Color(0xFF27272A);
  static const Color secondaryForegroundDark = Color(0xFFFAFAFA);
  static const Color mutedDark = Color(0xFF262626);
  static const Color mutedForegroundDark = Color(0xFFA1A1AA);
  static const Color accentDark = Color(0xFF292524);
  static const Color accentForegroundDark = Color(0xFFFAFAFA);
  static const Color destructiveDark = Color(0xFF7F1D1D);
  static const Color destructiveForegroundDark = Color(0xFFFEF2F2);
  static const Color borderDark = Color(0xFF27272A);
  static const Color inputDark = Color(0xFF27272A);
  static const Color ringDark = Color(0xFF1EC84B);

  // --- Semantic status ------------------------------------------------------
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
}

/// App-specific colours Material's [ColorScheme] has no slot for.
///
/// Read via `Theme.of(context).extension<AppPalette>()!`, never by branching
/// on brightness at the call site.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.success,
    required this.warning,
    required this.info,
    required this.muted,
    required this.mutedForeground,
    required this.border,
  });

  factory AppPalette.light() => const AppPalette(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    muted: AppColors.muted,
    mutedForeground: AppColors.mutedForeground,
    border: AppColors.border,
  );

  factory AppPalette.dark() => const AppPalette(
    success: AppColors.success,
    warning: AppColors.warning,
    info: AppColors.info,
    muted: AppColors.mutedDark,
    mutedForeground: AppColors.mutedForegroundDark,
    border: AppColors.borderDark,
  );

  final Color success;
  final Color warning;
  final Color info;
  final Color muted;
  final Color mutedForeground;
  final Color border;

  @override
  AppPalette copyWith({
    Color? success,
    Color? warning,
    Color? info,
    Color? muted,
    Color? mutedForeground,
    Color? border,
  }) {
    return AppPalette(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      border: border ?? this.border,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      info: Color.lerp(info, other.info, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
