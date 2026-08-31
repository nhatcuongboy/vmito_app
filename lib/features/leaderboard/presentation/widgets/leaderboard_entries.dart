import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _medalColors = <int, (Color, Color)>{
  1: (Color(0xFFF5B301), Color(0xFFFDE68A)),
  2: (Color(0xFFA8ADB8), Color(0xFFE2E5EA)),
  3: (Color(0xFFC1783C), Color(0xFFECCAA8)),
};

class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    required this.entries,
    required this.period,
    required this.onTap,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final ValueChanged<LeaderboardEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final ordered = [
      if (entries.length > 1) entries[1],
      entries[0],
      if (entries.length > 2) entries[2],
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final cardWidth = scale > 1.3
            ? 140.0
            : math.max(92, (constraints.maxWidth - 16) / 3).toDouble();
        final contentWidth = math.max(
          constraints.maxWidth,
          (cardWidth * ordered.length) + (8 * (ordered.length - 1)),
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < ordered.length; index++) ...[
                  SizedBox(
                    width: cardWidth,
                    child: _PodiumCard(
                      entry: ordered[index],
                      period: period,
                      onTap: () => onTap(ordered[index]),
                    ),
                  ),
                  if (index != ordered.length - 1)
                    const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PodiumCard extends StatelessWidget {
  const _PodiumCard({
    required this.entry,
    required this.period,
    required this.onTap,
  });

  final LeaderboardEntry entry;
  final LeaderboardPeriod period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final champion = entry.rank == 1;
    final medal = _medalColors[entry.rank] ?? _medalColors[3]!;
    final l10n = AppLocalizations.of(context);
    final name = entry.user.name?.trim().isNotEmpty ?? false
        ? entry.user.name!.trim()
        : '—';
    return Semantics(
      button: true,
      label: l10n.leaderboardRankSemantics(entry.rank, name, entry.points),
      child: Card(
        elevation: champion ? 5 : 1,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: champion
                ? medal.$1
                : Theme.of(context).extension<AppPalette>()!.border,
            width: champion ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('leaderboard-podium-${entry.rank}'),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.sm,
              champion ? AppSpacing.lg : AppSpacing.md,
              AppSpacing.sm,
              champion ? AppSpacing.lg : AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    LeaderboardAvatar(
                      name: name,
                      imageUrl: entry.user.image,
                      radius: champion ? 36 : 28,
                      borderColor: medal.$2,
                      borderWidth: 3,
                    ),
                    Positioned(
                      bottom: -8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: medal.$1,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          child: Text(
                            '${entry.rank}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: Center(
                    child: EmojiSafeText(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
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
                          fontSize: champion ? 23 : 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextSpan(
                        text: ' ${l10n.leaderboardPointsUnit}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(
                            context,
                          ).extension<AppPalette>()!.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                TierBadge(tier: entry.tier, compact: true),
                if (period != LeaderboardPeriod.all) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.leaderboardTotalPointsCaption(entry.totalPoints),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).extension<AppPalette>()!.mutedForeground,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LeaderboardRankRow extends StatelessWidget {
  const LeaderboardRankRow({
    required this.entry,
    required this.isMe,
    required this.onTap,
    super.key,
  });

  final LeaderboardEntry entry;
  final bool isMe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    final name = entry.user.name?.trim().isNotEmpty ?? false
        ? entry.user.name!.trim()
        : '—';
    final rate = entry.matchesPlayed == 0
        ? null
        : (entry.matchesWon * 100 / entry.matchesPlayed).round();
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Semantics(
      button: true,
      label: l10n.leaderboardRankSemantics(entry.rank, name, entry.points),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isMe
            ? theme.colorScheme.primaryContainer.withValues(alpha: .35)
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: isMe ? theme.colorScheme.primary : palette.border,
          ),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('leaderboard-rank-${entry.rank}'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${entry.rank}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  LeaderboardAvatar(
                    name: name,
                    imageUrl: entry.user.image,
                    radius: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: 2,
                          children: [
                            EmojiSafeText(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
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
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          rate == null
                              ? l10n.leaderboardNoMatches
                              : '${l10n.leaderboardWinRate(rate)} '
                                    '${l10n.leaderboardMatchRecord(entry.matchesWon, entry.matchesPlayed)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!largeText) ...[
                        TierBadge(tier: entry.tier, compact: true),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${entry.points}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' ${l10n.leaderboardPointsUnit}',
                              style: TextStyle(
                                fontSize: 10,
                                color: palette.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
