import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TierBadge extends StatelessWidget {
  const TierBadge({
    required this.tier,
    this.compact = false,
    this.brightness,
    super.key,
  });

  final RankingTier tier;
  final bool compact;

  /// Overrides the ambient theme — the share card rasterizes on white even when
  /// the app is in dark mode.
  final Brightness? brightness;

  @override
  Widget build(BuildContext context) {
    final visuals = tierVisualsFor(
      brightness ?? Theme.of(context).brightness,
      tier,
    );
    final label = tierLabel(AppLocalizations.of(context), tier);
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: visuals.background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : AppSpacing.sm,
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

/// The tier's emoji for the current theme — used by the rules sheet.
String tierEmojiFor(BuildContext context, RankingTier tier) =>
    tierVisualsFor(Theme.of(context).brightness, tier).emoji;
