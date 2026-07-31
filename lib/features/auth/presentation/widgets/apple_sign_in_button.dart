import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// "Sign in with Apple", styled to Apple's Human Interface Guidelines.
///
/// **Mandatory on iOS** (App Store Review Guideline 4.8) because the app also
/// offers Google and Facebook login. The guideline also requires it be
/// presented no less prominently than the other options — hence the same size
/// and position in the stack, not a smaller secondary link.
///
/// Hidden on Android, where the native credential is unavailable. A web-based
/// Apple flow exists but needs a Services ID and a server-side redirect; until
/// that is set up, showing a button that cannot work is worse than showing
/// none.
class AppleSignInButton extends ConsumerStatefulWidget {
  const AppleSignInButton({this.onError, this.enabled = true, super.key});

  /// Reports a failure so the host screen can render it inline, next to
  /// whatever error the email form is already using.
  final void Function(String message)? onError;
  final bool enabled;

  /// Whether this platform can complete a native Apple sign-in at all.
  static bool get isSupported => Platform.isIOS || Platform.isMacOS;

  @override
  ConsumerState<AppleSignInButton> createState() => _AppleSignInButtonState();
}

class _AppleSignInButtonState extends ConsumerState<AppleSignInButton> {
  bool _isSubmitting = false;

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSubmitting = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        widget.onError?.call(l10n.authAppleNoToken);
        return;
      }

      // givenName/familyName are populated on the FIRST authorization only.
      // Apple never sends them again, so they go straight to the backend now
      // or the account stays nameless forever.
      await ref
          .read(authControllerProvider.notifier)
          .signInWithApple(
            identityToken: identityToken,
            givenName: credential.givenName,
            familyName: credential.familyName,
          );
      // No navigation here: the router redirect reacts to auth status.
    } on SignInWithAppleAuthorizationException catch (error) {
      // Cancelling is a normal outcome, not a failure to report.
      if (error.code != AuthorizationErrorCode.canceled) {
        AppLogger.warn('apple sign-in failed', error: error);
        widget.onError?.call(l10n.authAppleFailed);
      }
    } on ApiException catch (error) {
      widget.onError?.call(error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppleSignInButton.isSupported) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final busy = _isSubmitting || !widget.enabled;

    return SizedBox(
      height: 48,
      child: SignInWithAppleButton(
        onPressed: busy ? () {} : _signIn,
        text: AppLocalizations.of(context).authSignInWithApple,
        // Apple requires the mark to keep its contrast against the background;
        // white-on-dark and black-on-light are the sanctioned pairings.
        style: isDark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    );
  }
}
