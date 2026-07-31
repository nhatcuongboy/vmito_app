import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Confirms and performs account deletion.
///
/// App Store Guideline 5.1.1(v) requires in-app account deletion, and requires
/// it be genuinely reachable — this is two taps from the Profile tab.
///
/// A bare "are you sure?" would be dishonest for an irreversible action that
/// does *not* erase everything: sessions the user hosted and the payment
/// ledger survive, anonymized, because they are also other players' records.
/// Saying so here is the difference between a user consenting and a user being
/// surprised.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    // Modal: a mis-tap outside should not leave a half-started deletion.
    barrierDismissible: false,
    builder: (context) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _isDeleting = false;
  String? _error;

  Future<void> _delete() async {
    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Close on success only. The router redirect reacts to the auth state
      // change and returns the user to a signed-out screen.
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return AlertDialog(
      title: Text(l10n.accountDeleteTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.accountDeleteWarning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Bullet(
              icon: Icons.delete_outline_rounded,
              text: l10n.accountDeleteRemoved,
            ),
            _Bullet(
              icon: Icons.visibility_off_outlined,
              text: l10n.accountDeleteRetained,
            ),
            _Bullet(
              icon: Icons.lock_outline_rounded,
              text: l10n.accountDeleteCannotSignIn,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: _isDeleting ? null : _delete,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            // The destructive action is not the visual default: it sits second
            // and carries the error colour, so it cannot be hit by momentum.
            minimumSize: const Size(0, 44),
          ),
          child: _isDeleting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.muted,
                  ),
                )
              : Text(l10n.accountDeleteConfirm),
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.mutedForeground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}
