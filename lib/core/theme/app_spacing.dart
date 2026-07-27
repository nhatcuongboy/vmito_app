/// Spacing and radius scale.
///
/// Matches the Tailwind scale the web app uses (4 px base) so a `p-4` on web
/// translates to [AppSpacing.md] here without arithmetic at the call site.
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal gutter for full-width screens.
  static const double screenPadding = 16;
}

/// `--radius: 0.5rem` in globals.css, with the same ±2 px derivations.
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 6;
  static const double lg = 8;
  static const double xl = 12;
  static const double pill = 999;
}

/// Minimum tap target. Do not go below this — it is the accessibility floor on
/// both platforms, and courts/player chips are dense enough to tempt it.
abstract final class AppSizes {
  static const double minTapTarget = 48;
  static const double appBarHeight = 56;
  static const double bottomNavHeight = 64;

  /// Badminton court aspect ratio, from `BadmintonCourt.tsx:66`.
  /// Vertical orientation is a coordinate transform of this, not a second
  /// widget tree. See docs/PORTING_GUIDE.md.
  static const double courtAspectRatio = 13.4 / 6.1;
}
