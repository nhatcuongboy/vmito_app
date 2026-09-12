import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';

/// Shown while `AuthController.restoreSession` resolves.
///
/// The router holds every navigation here until auth status is known, so this
/// is on screen for exactly one Keychain read plus one `/users/me` call.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  /// Logo height as a fraction of the screen height.
  ///
  /// 18 % gives an appropriately prominent hero on every device:
  /// - iPhone SE  (568 px) → 102 px (clamped to 100 px)
  /// - iPhone 14  (852 px) → 153 px
  /// - iPad mini  (1133 px) → 180 px (clamped)
  /// - iPad Pro 12.9" (1366 px) → 180 px (clamped)
  static const double _logoHeightFraction = 0.18;
  static const double _logoHeightMin = 100.0;
  static const double _logoHeightMax = 180.0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final logoHeight = (screenHeight * _logoHeightFraction).clamp(
      _logoHeightMin,
      _logoHeightMax,
    );

    // Font sizes scale with the logo but stay within readable bounds.
    final vmitoFontSize = (logoHeight * 0.38).clamp(38.0, 68.0);
    final sloganFontSize = (logoHeight * 0.085).clamp(9.0, 15.0);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // FittedBox is kept as a safety net for unexpected constraints
          // (e.g. landscape mode on iPhone SE) but should rarely fire now
          // that the logo is vertical and its height is already responsive.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(
                  height: logoHeight,
                  axis: Axis.vertical,
                  vmitoFontSize: vmitoFontSize,
                  sloganFontSize: sloganFontSize,
                ),
                const SizedBox(height: AppSpacing.xl),
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
