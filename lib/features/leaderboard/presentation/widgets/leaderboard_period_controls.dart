import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class LeaderboardPeriodTabs extends StatelessWidget {
  const LeaderboardPeriodTabs({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final LeaderboardPeriod selected;
  final ValueChanged<LeaderboardPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = math.max(constraints.maxWidth / 4, 96);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.muted,
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                children: [
                  for (final period in leaderboardPeriods)
                    SizedBox(
                      width: itemWidth - 8,
                      child: _PeriodTab(
                        period: period,
                        selected: selected == period,
                        onTap: () => onSelected(period),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.period,
    required this.selected,
    required this.onTap,
  });

  final LeaderboardPeriod period;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      elevation: selected ? 1 : 0,
      child: InkWell(
        key: ValueKey('leaderboard-period-${period.wireValue}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                periodLabel(AppLocalizations.of(context), period),
                maxLines: 1,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.extension<AppPalette>()!.mutedForeground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final options = recentLeaderboardPeriods(period);
    final selected = options.firstWhere(
      (option) => option.key == periodKey,
      orElse: () => options.first,
    );
    return OutlinedButton.icon(
      key: const ValueKey('leaderboard-period-picker'),
      onPressed: onTap,
      iconAlignment: IconAlignment.end,
      icon: const Icon(AppIcons.arrowDownward, size: 16),
      label: Text(
        periodOptionLabel(AppLocalizations.of(context), period, selected),
      ),
    );
  }
}

class LeaderboardCountdown extends StatefulWidget {
  const LeaderboardCountdown({
    required this.endsAt,
    required this.isCurrent,
    super.key,
  });

  final DateTime? endsAt;
  final bool isCurrent;

  @override
  State<LeaderboardCountdown> createState() => _LeaderboardCountdownState();
}

class _LeaderboardCountdownState extends State<LeaderboardCountdown> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  @override
  void didUpdateWidget(covariant LeaderboardCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt ||
        oldWidget.isCurrent != widget.isCurrent) {
      _restart();
    }
  }

  void _restart() {
    _timer?.cancel();
    _tick();
    if (widget.endsAt != null && widget.isCurrent) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    }
  }

  void _tick() {
    final end = widget.endsAt;
    final next = end?.difference(DateTime.now());
    if (mounted) setState(() => _remaining = next);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = Theme.of(context).extension<AppPalette>()!.mutedForeground;
    if (widget.endsAt == null) return const SizedBox.shrink();
    if (!widget.isCurrent) {
      return Text(
        l10n.leaderboardCountdownClosed,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
      );
    }
    final remaining = _remaining;
    if (remaining == null) return const SizedBox.shrink();
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final days = safe.inDays;
    final value = days > 0
        ? '${l10n.leaderboardCountdownDays(days)} '
              '${l10n.leaderboardCountdownHours(safe.inHours % 24)}'
        : '${l10n.leaderboardCountdownHours(safe.inHours)} '
              '${l10n.leaderboardCountdownMinutes(safe.inMinutes % 60)}';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${l10n.leaderboardCountdownEndsIn} ',
            style: TextStyle(color: muted, fontWeight: FontWeight.w400),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      textAlign: TextAlign.end,
      style: Theme.of(context).textTheme.bodySmall,
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
