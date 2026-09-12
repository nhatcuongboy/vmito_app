import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Visible pill height. The tap area around it is [AppSizes.compactTapTarget]
/// tall, so the control stays hittable at a smaller visual size.
///
/// It is filled, not outlined: the countdown beside it is a *filled* chip, and
/// an outlined control next to a filled one reads as the lesser of the two —
/// backwards, since this is the interactive element and the countdown is only
/// information.
const _pillHeight = 32.0;

class LeaderboardPeriodButton extends StatelessWidget {
  const LeaderboardPeriodButton({
    required this.period,
    required this.periodKey,
    required this.onTap,
    super.key,
  });

  final LeaderboardPeriod period;
  final String? periodKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final options = recentLeaderboardPeriods(period);
    final selected = options.firstWhere(
      (option) => option.key == periodKey,
      orElse: () => options.first,
    );
    final radius = BorderRadius.circular(AppRadius.pill);
    return InkWell(
      key: const ValueKey('leaderboard-period-picker'),
      onTap: onTap,
      borderRadius: radius,
      child: SizedBox(
        height: AppSizes.compactTapTarget,
        child: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.brandSurface,
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: .30),
              ),
              borderRadius: radius,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _pillHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.calendar,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    // Period labels vary in length ("Tuần này" vs "Tháng
                    // 12/2026"); let the label give way instead of the row
                    // overflowing at large text scales.
                    Flexible(
                      child: Text(
                        periodOptionLabel(
                          AppLocalizations.of(context),
                          period,
                          selected,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      AppIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String periodLabel(AppLocalizations l10n, LeaderboardPeriod period) =>
    switch (period) {
      LeaderboardPeriod.week => l10n.leaderboardPeriodWeek,
      LeaderboardPeriod.month => l10n.leaderboardPeriodMonth,
      LeaderboardPeriod.season => l10n.leaderboardPeriodSeason,
      LeaderboardPeriod.all ||
      LeaderboardPeriod.year => l10n.leaderboardPeriodAll,
    };

String periodOptionLabel(
  AppLocalizations l10n,
  LeaderboardPeriod period,
  LeaderboardPeriodOption option,
) {
  if (option.isCurrent) {
    return switch (period) {
      LeaderboardPeriod.week => l10n.leaderboardCurrentWeek,
      LeaderboardPeriod.month => l10n.leaderboardCurrentMonth,
      LeaderboardPeriod.season => l10n.leaderboardCurrentSeason,
      LeaderboardPeriod.year || LeaderboardPeriod.all => '${option.year}',
    };
  }
  return switch (period) {
    LeaderboardPeriod.week => l10n.leaderboardWeekLabel(option.week),
    LeaderboardPeriod.month => l10n.leaderboardMonthLabel(
      option.month,
      option.year,
    ),
    LeaderboardPeriod.season => switch (option.season) {
      1 => l10n.leaderboardSpringLabel(option.year),
      2 => l10n.leaderboardSummerLabel(option.year),
      3 => l10n.leaderboardAutumnLabel(option.year),
      _ => l10n.leaderboardWinterLabel(option.year),
    },
    LeaderboardPeriod.year || LeaderboardPeriod.all => '${option.year}',
  };
}
