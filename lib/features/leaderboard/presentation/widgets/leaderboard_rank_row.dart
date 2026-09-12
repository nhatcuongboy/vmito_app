import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/emoji_safe_text.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_avatar.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/tier_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Ranks at or above this keep full-contrast numerals — the visible top of the
/// board. Below it the rank recedes so names carry the row.
const _prominentRankCutoff = 10;

/// Fixed so the points read as a column rather than a ragged right edge.
const _pointsColumnWidth = 62.0;

const _largeTextScale = 1.3;

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
    final largeText =
        MediaQuery.textScalerOf(context).scale(1) > _largeTextScale;
    final radius = BorderRadius.circular(AppRadius.lg);

    return Semantics(
      button: true,
      label: l10n.leaderboardRankSemantics(entry.rank, name, entry.points),
      child: Material(
        color: isMe
            ? theme.colorScheme.primaryContainer.withValues(alpha: .35)
            : Colors.transparent,
        // `shape` and `borderRadius` are mutually exclusive on Material.
        shape: RoundedRectangleBorder(
          side: isMe
              ? BorderSide(color: theme.colorScheme.primary)
              : BorderSide.none,
          borderRadius: radius,
        ),
        child: InkWell(
          key: ValueKey('leaderboard-rank-${entry.rank}'),
          onTap: onTap,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(
                      '${entry.rank}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: entry.rank <= _prominentRankCutoff
                            ? theme.colorScheme.onSurface
                            : palette.mutedForeground,
                        fontWeight: FontWeight.w800,
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
                          runSpacing: AppSpacing.xxs,
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
                        const SizedBox(height: AppSpacing.xxs),
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
                  if (!largeText) ...[
                    const SizedBox(width: AppSpacing.xs),
                    TierBadge(tier: entry.tier, compact: true),
                  ],
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    width: largeText ? null : _pointsColumnWidth,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Numbers.decimal(
                              entry.points,
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
                      maxLines: 2,
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
