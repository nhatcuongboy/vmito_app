import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

/// Loading placeholder for the club detail "Thông báo" tab.
///
/// Mirrors the loaded tab's `Card`/`ListTile` rows (leading icon, title and
/// a two-line subtitle) so the list doesn't reflow once announcements arrive.
class ClubAnnouncementsSkeleton extends StatelessWidget {
  const ClubAnnouncementsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeletonList(
    listKey: const Key('club-announcements-skeleton-list'),
    itemExtentEstimate: 96,
    itemBuilder: (context) => const _AnnouncementRowSkeleton(),
  );
}

class _AnnouncementRowSkeleton extends StatelessWidget {
  const _AnnouncementRowSkeleton();

  @override
  Widget build(BuildContext context) => const Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: EdgeInsets.all(AppSpacing.md),
      child: AppShimmer(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeletonBox(width: 24, height: 24, radius: 12),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeletonBox(width: 140, height: 16, radius: AppRadius.md),
                  SizedBox(height: AppSpacing.xs + 2),
                  AppSkeletonBox(height: 12),
                  SizedBox(height: AppSpacing.xs),
                  AppSkeletonBox(width: 200, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
