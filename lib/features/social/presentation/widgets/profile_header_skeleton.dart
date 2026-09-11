import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Placeholder for the profile identity block below the cover: name, joined
/// date, level chip and the inline stats row.
///
/// Starts 60dp below the cover like the loaded `_ProfileHeader`, leaving room
/// for the avatar that overlaps the cover edge.
class ProfileIdentitySkeleton extends StatelessWidget {
  const ProfileIdentitySkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      60,
      AppSpacing.md,
      AppSpacing.md,
    ),
    child: AppShimmer(
      child: Column(
        children: [
          AppSkeletonBox(width: 168, height: 24, radius: AppRadius.md),
          SizedBox(height: AppSpacing.xs + 2),
          AppSkeletonBox(width: 120, height: 12),
          SizedBox(height: AppSpacing.sm),
          AppSkeletonBox(width: 96, height: 32, radius: AppRadius.pill),
          SizedBox(height: AppSpacing.sm + 4),
          SizedBox(
            height: AppSizes.minTapTarget,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppSkeletonBox(width: 80, height: 14),
                _StatDot(),
                AppSkeletonBox(width: 84, height: 14),
                _StatDot(),
                AppSkeletonBox(width: 60, height: 14),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatDot extends StatelessWidget {
  const _StatDot();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: AppSkeletonBox(width: 4, height: 4, radius: 2),
  );
}

/// Placeholder for the pinned profile tab bar, with the same separators as
/// the loaded `_ProfileTabBar`.
class ProfileTabBarSkeleton extends StatelessWidget {
  const ProfileTabBarSkeleton({super.key});

  /// Rough widths of the five tab labels, Posts first.
  static const _labelWidths = [56.0, 70.0, 80.0, 40.0, 62.0];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.dividerColor, width: .5),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: SizedBox(
        height: kTextTabBarHeight,
        child: AppShimmer(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                for (final width in _labelWidths)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: AppSkeletonBox(width: width, height: 14),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
