import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// The web app's `MyRegistrationModal`, as a bottom sheet.
Future<void> showMyRegistrationSheet(
  BuildContext context, {
  required String sessionId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder: (context) => _MyRegistrationSheet(sessionId: sessionId),
  );
}

class _MyRegistrationSheet extends ConsumerWidget {
  const _MyRegistrationSheet({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final registration = ref.watch(myRegistrationProvider(sessionId));

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.registrationMyTitle,
              style: theme.textTheme.titleLarge,
            ),
          ),
          Flexible(
            child: registration.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: AppLoadingView(),
              ),
              error: (error, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: AppErrorView(
                  error: error,
                  onRetry: () =>
                      ref.invalidate(myRegistrationProvider(sessionId)),
                ),
              ),
              data: (players) => players.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.registrationEmpty,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      children: [
                        for (final player in players)
                          _PlayerRow(player: player),
                      ],
                    ),
            ),
          ),
          if (registration.value?.any((p) => p.isPendingApproval) ?? false)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: FilledButton.tonalIcon(
                onPressed: () => _confirmWithdraw(context, ref),
                icon: const Icon(AppIcons.undo),
                label: Text(l10n.registrationWithdraw),
                style: FilledButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  backgroundColor: theme.colorScheme.error.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.registrationWithdraw,
      content: l10n.registrationWithdrawConfirm,
      confirmLabel: l10n.commonConfirm,
    );
    if (confirmed != true) return;

    final outcome = await ref
        .read(myRegistrationProvider(sessionId).notifier)
        .withdrawPending();

    // Some rows legitimately refuse: a guest row 403s because the backend's
    // guard ignores who created it, and a player already on court 400s.
    // Reporting plain success would tell the user their slot is gone when it
    // is not.
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome.isCompleteSuccess
              ? l10n.registrationWithdrawDone
              : l10n.registrationWithdrawPartial(outcome.failed),
        ),
      ),
    );
    navigator.pop();
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.player});

  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.playerName(player),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(status: player.registrationStatus),
            ],
          ),
          if (player.phone case final phone? when phone.trim().isNotEmpty)
            _MetaLine(icon: AppIcons.phone, text: phone),
          if (player.level case final level?)
            _MetaLine(
              icon: AppIcons.shield,
              text: l10n.levelName(level),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    final (label, color) = switch (status) {
      RegistrationStatus.approved => (
        l10n.registrationStatusApproved,
        palette.success,
      ),
      RegistrationStatus.pending => (
        l10n.registrationStatusPending,
        palette.warning,
      ),
      RegistrationStatus.rejected => (
        l10n.registrationStatusRejected,
        theme.colorScheme.error,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: palette.mutedForeground),
          const SizedBox(width: AppSpacing.xs + 2),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
