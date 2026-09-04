import 'package:flutter/material.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/biometric_sign_in_provider.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

String biometricSignInLabel(AppLocalizations l10n, BiometricKind kind) =>
    switch (kind) {
      BiometricKind.face => l10n.biometricSignInFaceTitle,
      BiometricKind.fingerprint => l10n.biometricSignInFingerprintTitle,
      BiometricKind.generic ||
      BiometricKind.unavailable => l10n.biometricSignInGenericTitle,
    };

/// Names the account the biometric shortcut would resume.
///
/// Without it the user cannot tell which account a face scan is about to sign
/// them into — the same reason VNeID shows the ID card above the password box.
class BiometricAccountCard extends StatelessWidget {
  const BiometricAccountCard({
    required this.offer,
    required this.onSwitchAccount,
    super.key,
  });

  final BiometricSignInOffer offer;
  final VoidCallback? onSwitchAccount;

  /// `nguyen@vmito.app` -> `ngu•••@vmito.app`. Shoulder-surfing protection
  /// only; the value is already on this device.
  static String _mask(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final visible = at < 3 ? 1 : 3;
    return '${email.substring(0, visible)}•••${email.substring(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final account = offer.account;
    final name = account.displayName.isNotEmpty
        ? account.displayName
        : account.email;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (account.email.isNotEmpty)
                    Text(
                      _mask(account.email),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              key: const Key('biometric-switch-account'),
              onPressed: onSwitchAccount,
              child: Text(l10n.biometricSignInSwitchAccount),
            ),
          ],
        ),
      ),
    );
  }
}

/// The shortcut itself, shown beside the password field.
class BiometricSignInButton extends StatelessWidget {
  const BiometricSignInButton({
    required this.kind,
    required this.onPressed,
    super.key,
  });

  final BiometricKind kind;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = biometricSignInLabel(AppLocalizations.of(context), kind);
    return IconButton(
      key: const Key('signin-biometric-button'),
      icon: Icon(
        kind == BiometricKind.fingerprint
            ? AppIcons.fingerprint
            : AppIcons.biometric,
        color: Theme.of(context).colorScheme.primary,
      ),
      tooltip: label,
      onPressed: onPressed,
    );
  }
}
