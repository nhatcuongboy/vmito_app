import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_countdown.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_controls.dart';

const _stackedTextScale = 1.3;

class LeaderboardPeriodStatusRow extends StatelessWidget {
  const LeaderboardPeriodStatusRow({
    required this.period,
    required this.periodKey,
    required this.periodEnd,
    required this.isCurrentPeriod,
    required this.onSelectPeriod,
    super.key,
  });

  final LeaderboardPeriod period;
  final String? periodKey;
  final DateTime? periodEnd;
  final bool isCurrentPeriod;
  final VoidCallback onSelectPeriod;

  @override
  Widget build(BuildContext context) {
    final picker = LeaderboardPeriodButton(
      period: period,
      periodKey: periodKey,
      onTap: onSelectPeriod,
    );
    final countdown = LeaderboardCountdown(
      endsAt: periodEnd,
      isCurrent: isCurrentPeriod,
    );
    if (MediaQuery.textScalerOf(context).scale(1) > _stackedTextScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          picker,
          const SizedBox(height: AppSpacing.xs),
          Align(alignment: Alignment.centerRight, child: countdown),
        ],
      );
    }
    return SizedBox(
      height: AppSizes.compactRow,
      child: Row(
        children: [
          picker,
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Align(alignment: Alignment.centerRight, child: countdown),
          ),
        ],
      ),
    );
  }
}
