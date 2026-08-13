import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Shows a dialog prompting the guest user to sign in to access a feature.
///
/// If they click the Sign In button, they are redirected to the sign in page,
/// and the target route (or current URI path if not specified) is passed as a
/// `redirect` query parameter.
Future<void> showLoginPromptDialog(
  BuildContext context, {
  String? featureName,
  String? targetRoute,
}) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.loginRequired),
      content: Text(
        featureName != null
            ? l10n.loginRequiredFeature(featureName)
            : l10n.loginRequiredDescription,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.authSignIn),
        ),
      ],
    ),
  );

  if (confirmed == true && context.mounted) {
    final redirectUri = targetRoute ?? GoRouterState.of(context).uri.toString();
    unawaited(context.push(AppRoutes.signInWithRedirect(redirectUri)));
  }
}
