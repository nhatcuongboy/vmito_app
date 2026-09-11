import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_stat_badge.dart';

/// Pill badge marking a player as overall or gender MVP in the stats table.
class PlayerStatMvpBadge extends StatelessWidget {
  const PlayerStatMvpBadge({
    required this.label,
    required this.player,
    required this.minMatches,
    this.color = AppColors.warning,
    super.key,
  });
  final String label;
  final PlayerStatistics player;
  final int minMatches;
  final Color color;

  /// Shared with the gender chip — see [PlayerStatBadge.pink].
  static const Color femaleMvp = PlayerStatBadge.pink;

  @override
  Widget build(BuildContext context) => Tooltip(
    message:
        '${player.winRate.toStringAsFixed(0)}% · ${player.wins}/${player.totalMatches} · ≥ $minMatches',
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs + 2,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
