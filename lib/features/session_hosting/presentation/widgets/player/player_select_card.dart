import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session_hosting/application/live_wait_time_provider.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// One player in the assign sheet's list.
///
/// Ports the `PlayerGrid` card in
/// `vmito-fe/src/components/player/PlayerGrid.tsx`: status-tinted background
/// (orange while waiting), a solid blue border and check badge once picked.
/// The wait badge is the point of the whole card: a host picking the next
/// four is deciding who has been standing around longest.
class PlayerSelectCard extends StatelessWidget {
  const PlayerSelectCard({
    required this.player,
    this.isSelected = false,
    this.updateWaitTime = false,
    this.onTap,
    super.key,
  });

  final SessionPlayer player;
  final bool isSelected;
  final bool updateWaitTime;
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
    final colors = _statusColors(
      isSelected: isSelected,
      status: player.status,
    );

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: colors.background,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _NumberPill(number: player.playerNumber),
                      const Spacer(),
                      _WaitBadge(
                        player: player,
                        updateWaitTime: updateWaitTime,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.playerName(player),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      if (levelLabel != null) ...[
                        _LevelChip(label: levelLabel),
                        const SizedBox(width: AppSpacing.xxs),
                      ],
                      _GenderChip(gender: player.gender),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          l10n.playerMatchesCount(player.matchesPlayed),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.mutedForeground,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Icon, not colour alone, so a pick survives a colourblind
              // reader and a monochrome screen.
              if (isSelected)
                const Positioned(right: 0, bottom: 0, child: _SelectedBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card background/border: blue once picked, otherwise tinted by the
/// player's own status — matches `PLAYER_COLORS` in `PlayerGrid.tsx`.
({Color background, Color border}) _statusColors({
  required bool isSelected,
  required PlayerStatus status,
}) {
  if (isSelected) {
    return (
      background: const Color(0xFFDBEAFE),
      border: const Color(0xFF3B82F6),
    );
  }
  return switch (status) {
    PlayerStatus.ready => (
      background: const Color(0xFFFEF08A),
      border: const Color(0xFFEAB308),
    ),
    PlayerStatus.waiting => (
      background: const Color(0xFFFED7AA),
      border: const Color(0xFFF97316),
    ),
    PlayerStatus.playing => (
      background: const Color(0xFFBBF7D0),
      border: const Color(0xFF22C55E),
    ),
    PlayerStatus.inactive => (
      background: const Color(0xFFE5E7EB),
      border: const Color(0xFF9CA3AF),
    ),
    PlayerStatus.finished => (
      background: const Color(0xFFF9FAFB),
      border: const Color(0xFFE5E7EB),
    ),
  };
}

class _NumberPill extends StatelessWidget {
  const _NumberPill({required this.number});

  final int? number;

  @override
  Widget build(BuildContext context) {
    if (number == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        '#$number',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// How long this player has been off court.
///
/// The thresholds match the web's: over 15 minutes is urgent, over 10 is
/// getting there. Below that it is unremarkable and stays grey.
class _WaitBadge extends ConsumerWidget {
  const _WaitBadge({required this.player, required this.updateWaitTime});

  final SessionPlayer player;
  final bool updateWaitTime;

  static const _urgentMinutes = 15;
  static const _warningMinutes = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!player.isWaiting) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final minutes = ref
        .watch(
          liveWaitTimeProvider((
            playerId: player.id,
            baselineMinutes: player.currentWaitTime,
            isRunning: updateWaitTime && player.status == PlayerStatus.waiting,
          )),
        )
        .asData
        ?.value;
    final displayedMinutes = minutes ?? player.currentWaitTime;
    final colour = switch (displayedMinutes) {
      > _urgentMinutes => theme.colorScheme.error,
      > _warningMinutes => palette.warning,
      _ => palette.mutedForeground,
    };

    final l10n = AppLocalizations.of(context);
    final label = displayedMinutes >= 60
        ? l10n.playerWaitHoursMinutes(
            displayedMinutes ~/ 60,
            displayedMinutes % 60,
          )
        : l10n.playerWaitMinutes(displayedMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Translucent so it reads on every status colour behind it.
class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Solid icon-only chip, coloured per gender — matches `PlayerGrid.tsx`'s
/// gender `Badge`, defaulting to grey when unset.
class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.gender});

  final Gender? gender;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (gender) {
      Gender.male => (const Color(0xFF3182CE), Icons.male),
      Gender.female => (const Color(0xFFD53F8C), Icons.female),
      Gender.other => (const Color(0xFF805AD5), Icons.people),
      null => (const Color(0xFF718096), Icons.person),
    };

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }
}

/// Floating check mark, bottom-right — the only cue for "picked" once the
/// card border already turned blue.
class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, size: 13, color: Colors.white),
    );
  }
}
