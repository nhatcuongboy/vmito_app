import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Confirms and completes sign-out from any authenticated surface.
Future<void> showSignOutConfirmation(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.authSignOut),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320),
        child: Text(l10n.authSignOutConfirmation),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            MaterialLocalizations.of(dialogContext).cancelButtonLabel,
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.authSignOut),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  await ref.read(authControllerProvider.notifier).signOut();
  // [appRouterProvider] reacts to the auth-state change and redirects to
  // sign-in. Calling `context.go` here races that rebuild and can briefly
  // mount two AppShells at once.
}
