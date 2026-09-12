import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/leaderboard/application/my_rank_controller.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A pinned "Vị trí của bạn" bar. Web only shows this in a ≥1440px rail
/// (`LeaderboardContextRail.tsx`); on mobile it is the only way to find
/// yourself without paging blind.
///
/// Renders nothing — not an error — whenever the rank is unknowable: signed
/// out, a historical period (`GET /leaderboard/me` answers for current periods
/// only), or a failed request. Hidden for the top 3, who are already on the
/// podium.
class LeaderboardMyRankBar extends ConsumerWidget {
  const LeaderboardMyRankBar({
    required this.loadedEntry,
    required this.period,
    required this.isCurrentPeriod,
    required this.onTap,
    super.key,
  });

  /// The user's own row if it is already on screen — preferred over the network
  /// because it carries the tier.
  final LeaderboardEntry? loadedEntry;
  final LeaderboardPeriod period;
  final bool isCurrentPeriod;

  /// Null when the row is not loaded yet, which also makes the bar unpressable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();

    final entry = loadedEntry;
    if (entry != null) {
      if (entry.rank <= 3) return const SizedBox.shrink();
      return _Bar(
        name: user.name,
        imageUrl: user.image,
        rank: entry.rank,
        points: entry.points,
        tier: entry.tier,
        onTap: onTap,
      );
    }

    if (!isCurrentPeriod) return const SizedBox.shrink();
    final ranks = ref.watch(myLeaderboardRanksProvider);
    final mine = ranks.asData?.value.forPeriod(period);
    if (mine == null) return const SizedBox.shrink();
    if (mine.rank != null && mine.rank! <= 3) return const SizedBox.shrink();
    return _Bar(
      name: user.name,
      imageUrl: user.image,
      rank: mine.rank,
      points: mine.points,
      onTap: null,
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.name,
    required this.imageUrl,
    required this.rank,
    required this.points,
    required this.onTap,
    this.tier,
  });

  final String? name;
  final String? imageUrl;
  final int? rank;
  final int points;

  /// Absent when the rank came from `/leaderboard/me`, which carries no tier.
  final RankingTier? tier;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPalette>()!;
    // At large text scales the badge is the first thing to go, as in the rows.
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Material(
      elevation: 8,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.border)),
          ),
          child: InkWell(
            key: const ValueKey('leaderboard-my-rank-bar'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  LeaderboardAvatar(
                    name: name,
                    imageUrl: imageUrl,
                    radius: 16,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.leaderboardMyRankTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: palette.mutedForeground,
                          ),
                        ),
                        Text(
                          rank == null
                              ? l10n.leaderboardMyRankUnranked
                              : '#$rank',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (tier != null && !largeText) ...[
                    TierBadge(tier: tier!, compact: true),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  Flexible(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Numbers.decimal(
                              points,
                              locale: Localizations.localeOf(
                                context,
                              ).languageCode,
                              digits: 0,
                            ),
                            style: const TextStyle(
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
                      textAlign: TextAlign.end,
                    ),
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
