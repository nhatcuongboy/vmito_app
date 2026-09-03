import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';

/// Vertical brand tint ramp shared by the home app bar and the discovery
/// header, so the two separate widgets read as one continuous branded band.
@immutable
class HomeHeaderTint {
  const HomeHeaderTint({
    required this.strong,
    required this.mid,
    required this.soft,
    required this.surface,
    required this.accent,
  });

  factory HomeHeaderTint.of(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return HomeHeaderTint(
      strong: Color.lerp(
        scheme.surface,
        scheme.primary,
        isDark ? 0.32 : 0.26,
      )!,
      mid: Color.lerp(scheme.surface, scheme.primary, isDark ? 0.22 : 0.16)!,
      soft: theme.extension<AppPalette>()!.brandSurface,
      surface: scheme.surface,
      accent: scheme.primary,
    );
  }

  final Color strong;
  final Color mid;
  final Color soft;
  final Color surface;
  final Color accent;

  /// Top of the band: the app bar itself.
  LinearGradient get appBarGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [strong, mid],
  );

  /// Bottom of the band: tabs + toolbar fading into the page surface.
  LinearGradient get headerGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [mid, soft, surface],
    stops: const [0, 0.5, 1],
  );

  /// Soft, subtle vertical gradient for the drawer profile header.
  /// Fades smoothly from a gentle brand tint at the top down into the drawer surface.
  LinearGradient get drawerHeaderGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color.lerp(surface, mid, 0.65)!,
      Color.lerp(surface, soft, 0.7)!,
      surface,
    ],
    stops: const [0.0, 0.55, 1.0],
  );
}

/// Decorative brand backdrop for the home app bar: a diagonal brand wash, two
/// soft glows and a shuttlecock watermark bleeding off the right edge.
class HomeHeaderBackdrop extends StatelessWidget {
  const HomeHeaderBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final tint = HomeHeaderTint.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: tint.appBarGradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              right: -70,
              top: -90,
              child: _Glow(
                color: tint.accent,
                size: 220,
                alpha: isDark ? 0.34 : 0.28,
              ),
            ),
            Positioned(
              left: -60,
              bottom: -70,
              child: _Glow(
                color: tint.accent,
                size: 170,
                alpha: isDark ? 0.26 : 0.22,
              ),
            ),
            Positioned(
              right: -26,
              bottom: -12,
              child: Opacity(
                opacity: isDark ? 0.18 : 0.14,
                child: Transform.rotate(
                  angle: -0.35,
                  child: Image.asset(
                    'assets/icons/shuttlecock.png',
                    width: 104,
                    height: 104,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.color,
    required this.size,
    required this.alpha,
  });

  final Color color;
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}
