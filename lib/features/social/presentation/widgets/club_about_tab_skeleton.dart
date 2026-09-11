import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Placeholder for the default "Giới thiệu" tab: description, location and
/// host cards, mirroring `_about()`'s `_card()`-shaped sections.
///
/// Each card's chrome stays a static [Card] — only its content shimmers —
/// same technique as `UserAchievementsSkeleton`'s panels.
class ClubAboutTabSkeleton extends StatelessWidget {
  const ClubAboutTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: const Padding(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DescriptionCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            _LocationCardSkeleton(),
            SizedBox(height: AppSpacing.md),
            _HostCardSkeleton(),
          ],
        ),
      ),
    ),
  );
}

/// Static chrome shared by every about-tab card, matching `_card()`.
class _AboutCardSkeleton extends StatelessWidget {
  const _AboutCardSkeleton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AppShimmer(child: child),
    ),
  );
}

class _DescriptionCardSkeleton extends StatelessWidget {
  const _DescriptionCardSkeleton();

  @override
  Widget build(BuildContext context) => const _AboutCardSkeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeletonBox(width: 120, height: 16, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        AppSkeletonBox(height: 12),
        SizedBox(height: AppSpacing.xs + 2),
        AppSkeletonBox(height: 12),
        SizedBox(height: AppSpacing.xs + 2),
        AppSkeletonBox(width: 200, height: 12),
      ],
    ),
  );
}

class _LocationCardSkeleton extends StatelessWidget {
  const _LocationCardSkeleton();

  @override
  Widget build(BuildContext context) => const _AboutCardSkeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeletonBox(width: 90, height: 16, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        AppSkeletonBox(height: 96, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.sm),
        AppSkeletonBox(width: 160, height: 14),
        SizedBox(height: AppSpacing.xs),
        AppSkeletonBox(width: 220, height: 12),
        SizedBox(height: AppSpacing.sm),
        AppSkeletonBox(width: 110, height: 32, radius: AppRadius.md),
      ],
    ),
  );
}

class _HostCardSkeleton extends StatelessWidget {
  const _HostCardSkeleton();

  @override
  Widget build(BuildContext context) => const _AboutCardSkeleton(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSkeletonBox(width: 100, height: 16, radius: AppRadius.md),
        SizedBox(height: AppSpacing.md),
        Row(
          children: [
            AppSkeletonBox(width: 40, height: 40, radius: 20),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: AppSkeletonBox(height: 16)),
          ],
        ),
      ],
    ),
  );
}
