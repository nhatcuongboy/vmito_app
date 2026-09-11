import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Small pill showing a session's status, colour-coded by [SessionStatus].
/// Used in AppBars on both the host and player session screens.
class SessionStatusBadge extends StatelessWidget {
  const SessionStatusBadge({required this.status, super.key});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final (label, color) = switch (status) {
      SessionStatus.preparing => (
        l10n.sessionStatusPreparing,
        palette.mutedForeground,
      ),
      SessionStatus.inProgress => (
        l10n.sessionStatusInProgress,
        palette.success,
      ),
      SessionStatus.finished => (
        l10n.sessionStatusFinished,
        palette.mutedForeground,
      ),
      SessionStatus.cancelled => (l10n.sessionStatusCancelled, palette.warning),
    };

    return Container(
      key: const Key('host-session-status-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
