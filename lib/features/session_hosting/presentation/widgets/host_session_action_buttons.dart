import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

/// Start-session button for the host overview tab's sticky action bar.
class HostStartSessionButton extends ConsumerWidget {
  const HostStartSessionButton({required this.sessionId, super.key});
  final String sessionId;

  Future<void> _handlePress(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.submit,
      title: l10n.startSessionConfirmTitle,
      content: l10n.startSessionConfirm,
      confirmLabel: l10n.startSessionAction,
      confirmKey: const ValueKey('confirm-start-session'),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(hostSessionManagementControllerProvider(sessionId).notifier)
          .startSession();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('start-session'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
        ),
        onPressed: () => _handlePress(context, ref),
        icon: const Icon(AppIcons.play, size: 18),
        label: Text(l10n.hostManageStartSession),
      ),
    );
  }
}

/// End-session button for the host overview tab's sticky action bar.
class HostEndSessionButton extends ConsumerWidget {
  const HostEndSessionButton({required this.sessionId, super.key});
  final String sessionId;

  Future<void> _handlePress(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.endSessionConfirmTitle,
      content: l10n.endSessionConfirm,
      confirmLabel: l10n.endSessionAction,
      confirmKey: const ValueKey('confirm-end-session'),
    );
    if (confirmed == true && context.mounted) {
      await ref
          .read(hostSessionManagementControllerProvider(sessionId).notifier)
          .endSession();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const ValueKey('end-session'),
        style: FilledButton.styleFrom(
          backgroundColor: theme.colorScheme.error,
          foregroundColor: theme.colorScheme.onError,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
        ),
        onPressed: () => _handlePress(context, ref),
        icon: const Icon(AppIcons.stop, size: 18),
        label: Text(l10n.hostManageEndSession),
      ),
    );
  }
}
