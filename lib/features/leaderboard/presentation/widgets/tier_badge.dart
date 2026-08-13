import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TierVisuals {
  const TierVisuals({
    required this.background,
    required this.foreground,
    required this.solid,
    required this.emoji,
  });

  final Color background;
  final Color foreground;
  final Color solid;
  final String emoji;
}

const tierVisuals = <RankingTier, TierVisuals>{
  RankingTier.bronze: TierVisuals(
    background: Color(0xFFF5E0D0),
    foreground: Color(0xFF8D5524),
    solid: Color(0xFFCD7F32),
    emoji: '🥉',
  ),
  RankingTier.silver: TierVisuals(
    background: Color(0xFFE8E8EE),
    foreground: Color(0xFF5A5A6E),
    solid: Color(0xFF9EA3B0),
    emoji: '🥈',
  ),
  RankingTier.gold: TierVisuals(
    background: Color(0xFFFDF0C8),
    foreground: Color(0xFF8A6D00),
    solid: Color(0xFFE6B800),
    emoji: '🥇',
  ),
  RankingTier.platinum: TierVisuals(
    background: Color(0xFFD9F4F0),
    foreground: Color(0xFF0E6E63),
    solid: Color(0xFF2EC4B6),
    emoji: '💠',
  ),
  RankingTier.diamond: TierVisuals(
    background: Color(0xFFE0ECFF),
    foreground: Color(0xFF1D4FD7),
    solid: Color(0xFF5B8DEF),
    emoji: '💎',
  ),
};

class TierBadge extends StatelessWidget {
  const TierBadge({required this.tier, this.compact = false, super.key});

  final RankingTier tier;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visuals = tierVisuals[tier]!;
    final label = tierLabel(AppLocalizations.of(context), tier);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: 3,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.shield,
                size: compact ? 11 : 13,
                color: visuals.solid,
              ),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    color: visuals.foreground,
                    fontSize: compact ? 10 : 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String tierLabel(AppLocalizations l10n, RankingTier tier) => switch (tier) {
  RankingTier.bronze => l10n.leaderboardTierBronze,
  RankingTier.silver => l10n.leaderboardTierSilver,
  RankingTier.gold => l10n.leaderboardTierGold,
  RankingTier.platinum => l10n.leaderboardTierPlatinum,
  RankingTier.diamond => l10n.leaderboardTierDiamond,
};
