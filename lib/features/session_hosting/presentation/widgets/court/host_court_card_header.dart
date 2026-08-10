import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/match_elapsed_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// Court number, name, elapsed time and status — the card's top row.
class HostCourtCardHeader extends StatelessWidget {
  const HostCourtCardHeader({required this.court, super.key});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final startTime = court.currentMatch?.startTime;

    final (statusLabel, statusColor, statusIcon) = switch (court.status) {
      CourtStatus.inUse => (
        l10n.courtStatusPlaying,
        palette.success,
        AppIcons.playCircle,
      ),
      CourtStatus.ready => (
        l10n.courtStatusReady,
        palette.warning,
        AppIcons.clock,
      ),
      CourtStatus.empty => (
        l10n.courtStatusEmpty,
        palette.mutedForeground,
        AppIcons.circle,
      ),
    };

    return Row(
      children: [
        _NumberBadge(number: court.courtNumber, color: statusColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            l10n.courtName(court),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Only a running match has a clock worth showing.
        if (court.status == CourtStatus.inUse && startTime != null) ...[
          MatchElapsedBadge(startTime: startTime),
          const SizedBox(width: AppSpacing.xs),
        ],
        // Icon plus text, never colour alone.
        Icon(statusIcon, size: 14, color: statusColor),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          statusLabel,
          style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
        ),
      ],
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.color});

  final int number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
