import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// One player in the assign sheet's list.
///
/// Ports the `PlayerGrid` card in `vmito-fe/src/components/player/`. The wait
/// badge is the point of the whole card: a host picking the next four is
/// deciding who has been standing around longest.
class PlayerSelectCard extends StatelessWidget {
  const PlayerSelectCard({
    required this.player,
    this.isSelected = false,
    this.onTap,
    super.key,
  });

  final SessionPlayer player;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final level = player.level;
    // Null for an unrated player, and for a level the table does not know —
    // an absent chip reads as missing data, a raw number reads as real data.
    final levelLabel = level == null ? null : levelShortLabel(level);

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : palette.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _NumberPill(number: player.playerNumber),
                  const Spacer(),
                  _WaitBadge(player: player),
                  // Icon, not colour alone, so selection survives a colourblind
                  // reader and a monochrome screen.
                  if (isSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xxs),
                      child: Icon(
                        AppIcons.checkCircle,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.playerName(player),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  if (levelLabel != null)
                    _Chip(label: levelLabel, palette: palette),
                  if (player.gender != null) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      _genderIcon(player.gender!),
                      size: 14,
                      color: palette.mutedForeground,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    l10n.playerMatchesCount(player.matchesPlayed),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _genderIcon(Gender gender) => switch (gender) {
    Gender.male => AppIcons.user,
    Gender.female => AppIcons.user,
    Gender.other => AppIcons.profile,
  };
}

class _NumberPill extends StatelessWidget {
  const _NumberPill({required this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    if (number == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '#$number',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onTertiaryContainer,
        ),
      ),
    );
  }
}

/// How long this player has been off court.
///
/// The thresholds match the web's: over 15 minutes is urgent, over 10 is
/// getting there. Below that it is unremarkable and stays grey.
class _WaitBadge extends StatelessWidget {
  const _WaitBadge({required this.player});

  final SessionPlayer player;

  static const _urgentMinutes = 15;
  static const _warningMinutes = 10;

  @override
  Widget build(BuildContext context) {
    if (!player.isWaiting) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final minutes = player.currentWaitTime;
    final colour = switch (minutes) {
      > _urgentMinutes => theme.colorScheme.error,
      > _warningMinutes => palette.warning,
      _ => palette.mutedForeground,
    };

    final l10n = AppLocalizations.of(context);
    final label = minutes >= 60
        ? l10n.playerWaitHoursMinutes(minutes ~/ 60, minutes % 60)
        : l10n.playerWaitMinutes(minutes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.palette});

  final String label;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: palette.muted,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: palette.mutedForeground),
      ),
    );
  }
}
