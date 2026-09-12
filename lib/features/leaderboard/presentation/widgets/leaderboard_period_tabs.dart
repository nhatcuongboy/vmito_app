import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_period_controls.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Above this text scale the labels stop fitting in equal quarters, so the row
/// falls back to scrolling with a static selected pill.
const _scrollingTextScale = 1.3;
const _scrollingTabWidth = 96.0;

/// Matches the felt duration of the web tabs' framer-motion spring
/// (`layoutId="leaderboard-period-tab"`, stiffness 420 / damping 34).
const _slideDuration = Duration(milliseconds: 220);

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
    final scrolling =
        MediaQuery.textScalerOf(context).scale(1) > _scrollingTextScale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.muted,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: scrolling ? _buildScrolling() : _buildSliding(context),
      ),
    );
  }

  Widget _buildScrolling() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final period in leaderboardPeriods)
          SizedBox(
            width: _scrollingTabWidth,
            child: _PeriodTab(
              period: period,
              selected: selected == period,
              showOwnPill: true,
              onTap: () => onSelected(period),
            ),
          ),
      ],
    ),
  );

  Widget _buildSliding(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final tabWidth = constraints.maxWidth / leaderboardPeriods.length;
      final index = leaderboardPeriods.indexOf(selected);
      return SizedBox(
        height: AppSizes.compactTapTarget,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : _slideDuration,
              curve: Curves.easeOutCubic,
              left: tabWidth * (index < 0 ? 0 : index),
              width: tabWidth,
              top: 0,
              bottom: 0,
              child: Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                color: Theme.of(context).colorScheme.surface,
              ),
            ),
            Row(
              children: [
                for (final period in leaderboardPeriods)
                  SizedBox(
                    width: tabWidth,
                    child: _PeriodTab(
                      period: period,
                      selected: selected == period,
                      showOwnPill: false,
                      onTap: () => onSelected(period),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.period,
    required this.selected,
    required this.showOwnPill,
    required this.onTap,
  });

  final LeaderboardPeriod period;
  final bool selected;

  /// The scrolling fallback has no shared sliding pill behind it.
  final bool showOwnPill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: showOwnPill && selected
          ? theme.colorScheme.surface
          : Colors.transparent,
      borderRadius: radius,
      elevation: showOwnPill && selected ? 1 : 0,
      child: InkWell(
        key: ValueKey('leaderboard-period-${period.wireValue}'),
        onTap: onTap,
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.compactTapTarget,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: AnimatedDefaultTextStyle(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : _slideDuration,
                style: (theme.textTheme.labelMedium ?? const TextStyle())
                    .copyWith(
                      color: selected
                          ? theme.colorScheme.primary
                          : theme.extension<AppPalette>()!.mutedForeground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                child: Text(
                  periodLabel(AppLocalizations.of(context), period),
                  maxLines: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
