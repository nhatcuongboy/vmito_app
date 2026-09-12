import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// A registration status pill, shared across the session browse card, the
/// session detail hero, and any "join request" review surface (session or
/// club) so pending/approved/rejected reads identically everywhere.
class RegistrationStatusBadge extends StatelessWidget {
  const RegistrationStatusBadge({required this.status, super.key});

  final RegistrationStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (label, color, icon) = switch (status) {
      RegistrationStatus.pending => (
        l10n.registrationStatusPending,
        palette.warning,
        AppIcons.clock,
      ),
      RegistrationStatus.approved => (
        l10n.registrationStatusApproved,
        palette.success,
        AppIcons.check,
      ),
      RegistrationStatus.rejected => (
        l10n.registrationStatusRejected,
        theme.colorScheme.error,
        null,
      ),
    };

    return Container(
      key: const Key('session-registration-status-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              key: const Key('session-registration-status-icon'),
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
