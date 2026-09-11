import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Placeholder for the club identity block below the hero: logo, name and
/// the member-count/join-policy meta row.
///
/// Mirrors `_identity()`'s layout — centred, capped at 800dp — so the block
/// doesn't reflow once the club loads.
class ClubIdentitySkeleton extends StatelessWidget {
  const ClubIdentitySkeleton({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: AppShimmer(
          child: Row(
            children: [
              AppSkeletonBox(width: 64, height: 64, radius: 32),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeletonBox(width: 180, height: 22, radius: AppRadius.md),
                    SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        AppSkeletonBox(width: 16, height: 16, radius: 8),
                        SizedBox(width: AppSpacing.xs),
                        AppSkeletonBox(width: 140, height: 14),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Placeholder for the pinned `_ClubTabBar`, with the same border chrome as
/// the loaded bar.
class ClubTabBarSkeleton extends StatelessWidget {
  const ClubTabBarSkeleton({super.key});

  /// Rough widths of the five tab labels: Giới thiệu, Thành viên, Lịch sinh
  /// hoạt, Thông báo, Ảnh.
  static const _labelWidths = [70.0, 80.0, 100.0, 80.0, 40.0];

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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Row(
              children: [
                for (final width in _labelWidths)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
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
