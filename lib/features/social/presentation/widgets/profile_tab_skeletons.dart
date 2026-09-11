import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/features/social/presentation/widgets/social_post_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';

// Loading placeholders for the public-profile tabs. Each one is scrollable
// (the lists via `AppSkeletonList`) so the outer collapsing header still
// responds to drags while a tab's first request is pending.

/// Posts tab: post-card placeholders sized to the viewport.
class ProfilePostsSkeleton extends StatelessWidget {
  const ProfilePostsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeletonList(
    listKey: const Key('profile-posts-skeleton-list'),
    itemBuilder: (_) => const SocialPostCardSkeleton(),
    minItems: 2,
    maxItems: 5,
    itemExtentEstimate: 200,
    gap: 12,
  );
}

/// Hosted-sessions tab: session-card placeholders sized to the viewport.
class ProfileHostedSkeleton extends StatelessWidget {
  const ProfileHostedSkeleton({super.key});

  @override
  Widget build(BuildContext context) => AppSkeletonList(
    listKey: const Key('profile-hosted-skeleton-list'),
    itemBuilder: (_) => const SessionCardSkeleton(),
    maxItems: 6,
    itemExtentEstimate: 150,
    gap: 12,
  );
}

/// Clubs tab: one club-group card with a title and three club rows, matching
/// the loaded tab's `Card` + `ListTile` layout.
class ProfileClubsSkeleton extends StatelessWidget {
  const ProfileClubsSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: AppLocalizations.of(context).commonLoading,
    child: ExcludeSemantics(
      child: ListView(
        key: const Key('profile-clubs-skeleton'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: AppShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 32,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AppSkeletonBox(width: 140, height: 16),
                      ),
                    ),
                    _ClubRowPlaceholder(nameWidth: 150),
                    _ClubRowPlaceholder(nameWidth: 116),
                    _ClubRowPlaceholder(nameWidth: 132),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ClubRowPlaceholder extends StatelessWidget {
  const _ClubRowPlaceholder({required this.nameWidth});

  final double nameWidth;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: 12,
    ),
    child: Row(
      children: [
        const AppSkeletonBox(width: 40, height: 40, radius: 20),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeletonBox(width: nameWidth, height: 14),
              const SizedBox(height: 6),
              const AppSkeletonBox(width: 88, height: 11),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        const AppSkeletonBox(width: 16, height: 16),
      ],
    ),
  );
}
