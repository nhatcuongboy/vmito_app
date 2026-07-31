import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A court's occupancy at a glance.
///
/// **Not** the playable court board. `BadmintonCourtView` — the 767-line
/// `BadmintonCourt.tsx` with its 13.4:6.1 geometry, three modes and two
/// directions — belongs to the live session screen and is built separately.
/// This tile is what a public detail page needs: who is on, who is next.
class CourtTile extends StatelessWidget {
  const CourtTile({required this.court, super.key});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);

    final (label, color) = switch (court.status) {
      CourtStatus.inUse => (l10n.courtStatusPlaying, palette.success),
      CourtStatus.ready => (l10n.courtStatusReady, palette.warning),
      CourtStatus.empty => (l10n.courtStatusEmpty, palette.mutedForeground),
    };

    final occupants = court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : court.preSelectedPlayers;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: court.isPlaying
              ? color.withValues(alpha: 0.5)
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  court.customName ?? l10n.courtNumbered(court.courtNumber),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Icon plus text, never colour alone.
              Icon(
                court.isPlaying
                    ? Icons.play_circle_fill_rounded
                    : Icons.circle_outlined,
                size: 14,
                color: color,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (occupants.isEmpty)
            Text(
              l10n.courtNoPlayers,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            )
          else ...[
            if (court.currentPlayers.isEmpty && court.hasPreSelection)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  l10n.courtPreSelected,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.warning,
                  ),
                ),
              ),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final player in occupants)
                  Chip(
                    label: Text(
                      player.displayName ??
                          l10n.playerNumbered(player.playerNumber ?? 0),
                    ),
                    labelStyle: theme.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
