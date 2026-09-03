import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';

/// Shown while `AuthController.restoreSession` resolves.
///
/// The router holds every navigation here until auth status is known, so this
/// is on screen for exactly one Keychain read plus one `/users/me` call.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogo(height: 84),
            SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
