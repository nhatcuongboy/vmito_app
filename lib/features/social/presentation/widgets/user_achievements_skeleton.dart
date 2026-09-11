import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Loading placeholder for `UserAchievementsTab`.
///
/// Keeps the loaded tab's structure — tier hero card, rank grid (2 or 4
/// columns at the same 520dp breakpoint, capped at 760dp), 3-column stats grid
/// and point-history rows — so the content swaps in without reflow. Scrollable
/// so the outer profile header still collapses while the request is pending.
class UserAchievementsSkeleton extends StatelessWidget {
  const UserAchievementsSkeleton({super.key});

  static const _contentMaxWidth = 760.0;
  static const _wideRankGridBreakpoint = 520.0;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: AppLocalizations.of(context).commonLoading,
    child: ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth
              .clamp(0, _contentMaxWidth)
              .toDouble();
          final rankColumns = contentWidth >= _wideRankGridBreakpoint ? 4 : 2;
          return ListView(
            key: const Key('achievement-skeleton'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _HeroPlaceholder(),
                      const SizedBox(height: AppSpacing.md),
                      _PanelGrid(
                        columns: rankColumns,
                        count: 4,
                        childAspectRatio: 1.45,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _PanelGrid(
                        columns: 3,
                        count: 6,
                        childAspectRatio: 1.2,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      for (var index = 0; index < 3; index++)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _Panel(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppSkeletonBox(width: 150, height: 13),
                                      SizedBox(height: 6),
                                      AppSkeletonBox(width: 80, height: 10),
                                    ],
                                  ),
                                ),
                                AppSkeletonBox(width: 32, height: 14),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _HeroPlaceholder extends StatelessWidget {
  const _HeroPlaceholder();

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      side: BorderSide(color: skeletonPalette(Theme.of(context)).border),
    ),
    child: const Padding(
      padding: EdgeInsets.all(20),
      child: AppShimmer(
        child: Column(
          children: [
            AppSkeletonBox(width: 86, height: 86, radius: 43),
            SizedBox(height: AppSpacing.sm),
            AppSkeletonBox(width: 150, height: 22, radius: AppRadius.md),
            SizedBox(height: AppSpacing.sm),
            AppSkeletonBox(width: 110, height: 36, radius: AppRadius.md),
            SizedBox(height: AppSpacing.sm),
            AppSkeletonBox(width: 76, height: 26, radius: AppRadius.pill),
            SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AppSkeletonBox(width: 170, height: 12),
                  ),
                ),
                AppSkeletonBox(width: 32, height: 12),
              ],
            ),
            SizedBox(height: AppSpacing.xs),
            AppSkeletonBox(height: 8, radius: AppRadius.pill),
          ],
        ),
      ),
    ),
  );
}

/// Same sizing as the tab's `_FixedGrid`: fixed-aspect cells, `sm` gaps.
class _PanelGrid extends StatelessWidget {
  const _PanelGrid({
    required this.columns,
    required this.count,
    required this.childAspectRatio,
  });

  final int columns;
  final int count;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width =
          (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
      return Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (var index = 0; index < count; index++)
            SizedBox(
              width: width,
              height: width / childAspectRatio,
              child: const _Panel(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppSkeletonBox(width: 48, height: 10),
                    SizedBox(height: AppSpacing.xs + 2),
                    AppSkeletonBox(width: 40, height: 18),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

/// Static outlined surface with only its content shimmering.
class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: skeletonPalette(theme).border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: AppShimmer(child: child),
      ),
    );
  }
}
