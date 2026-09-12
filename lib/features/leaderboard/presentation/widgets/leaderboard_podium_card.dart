import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/medal_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_pulse_glow.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class LeaderboardPodiumCard extends StatelessWidget {
  const LeaderboardPodiumCard({
    required this.entry,
    required this.period,
    required this.isMe,
    required this.onTap,
    super.key,
  });

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    final champion = entry.rank == 1;
    final medal = medalVisualsFor(theme.brightness, entry.rank);
    final radius = BorderRadius.circular(AppRadius.xl);
    final name = entry.user.name?.trim().isNotEmpty ?? false
        ? entry.user.name!.trim()
        : '—';
    final rate = entry.matchesPlayed == 0
        ? null
        : (entry.matchesWon * 100 / entry.matchesPlayed).round();

    final card = Material(
      elevation: champion ? 6 : 1,
      borderRadius: radius,
      color: theme.colorScheme.surface,
      shadowColor: champion ? medal.solid.withValues(alpha: .55) : null,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          // A barely-there wash so #1 reads as gold without tinting the text.
          gradient: champion
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [medal.glow, theme.colorScheme.surface],
                )
              : null,
          border: Border.all(
            color: isMe
                ? theme.colorScheme.primary
                : champion
                ? medal.solid
                : palette.border,
            width: isMe || champion ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: ValueKey('leaderboard-podium-${entry.rank}'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: champion ? AppSpacing.lg : AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (champion)
                  Icon(AppIcons.crown, size: 20, color: medal.solid),
                if (champion) const SizedBox(height: AppSpacing.xs),
                MedalAvatar(
                  name: name,
                  imageUrl: entry.user.image,
                  rank: entry.rank,
                  radius: champion ? 38 : 28,
                ),
                const SizedBox(height: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Center(
                    child: EmojiSafeText(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (isMe)
                  Text(
                    l10n.leaderboardYou,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xxs),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: Numbers.decimal(
                          entry.points,
                          locale: Localizations.localeOf(context).languageCode,
                          digits: 0,
                        ),
                        style: TextStyle(
                          fontSize: champion ? 24 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' ${l10n.leaderboardPointsUnit}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TierBadge(tier: entry.tier, compact: true),
                if (rate != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  _Caption(l10n.leaderboardWinRateCompact(rate)),
                ],
                if (period != LeaderboardPeriod.all)
                  _Caption(
                    l10n.leaderboardTotalPointsCaption(entry.totalPoints),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: l10n.leaderboardRankSemantics(entry.rank, name, entry.points),
      child: isMe
          ? RankPulseGlow(
              color: theme.colorScheme.primary,
              borderRadius: radius,
              child: card,
            )
          : card,
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).extension<AppPalette>()!.mutedForeground,
    ),
  );
}
