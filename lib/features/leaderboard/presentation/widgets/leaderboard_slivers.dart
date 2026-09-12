import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_empty_state.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_podium.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_rank_row.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Clears the pinned "your position" bar so the last row is never covered.
const myRankBarClearance = 96.0;

/// The board itself: skeleton, error, empty, or podium + ranked rows.
///
/// A function rather than a widget so the slivers stay direct children of the
/// screen's `CustomScrollView`.
List<Widget> leaderboardContentSlivers(
  BuildContext context, {
  required LeaderboardState state,
  required String? currentUserId,
  required GlobalKey myRowKey,
  required Future<void> Function() onRetry,
  required ValueChanged<LeaderboardEntry> onOpenProfile,
}) {
  final l10n = AppLocalizations.of(context);
  if (state.isLoading && !state.hasLoaded) {
    return const [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        sliver: SliverToBoxAdapter(child: LeaderboardSkeleton()),
      ),
    ];
  }
  if (state.error != null && state.entries.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: AppErrorView(error: state.error!, onRetry: onRetry),
      ),
    ];
  }
  if (state.entries.isEmpty) {
    return [
      SliverFillRemaining(
        hasScrollBody: false,
        child: LeaderboardEmptyState(
          title: l10n.leaderboardEmptyTitle,
          description: l10n.leaderboardEmptyDescription,
        ),
      ),
    ];
  }

  const blockPadding = EdgeInsets.fromLTRB(
    AppSpacing.screenPadding,
    AppSpacing.sm + 4,
    AppSpacing.screenPadding,
    0,
  );
  final rest = state.entries.skip(3).toList(growable: false);
  return [
    SliverPadding(
      padding: blockPadding,
      sliver: SliverToBoxAdapter(
        child: LeaderboardPodium(
          entries: state.entries.take(3).toList(growable: false),
          period: state.period,
          currentUserId: currentUserId,
          onTap: onOpenProfile,
        ),
      ),
    ),
    SliverPadding(
      padding: blockPadding,
      sliver: SliverList.separated(
        itemCount: rest.length,
        // Hairline rows instead of a stack of bordered cards.
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 42),
        itemBuilder: (context, index) {
          final entry = rest[index];
          final isMe = entry.user.id == currentUserId;
          return LeaderboardRankRow(
            key: isMe ? myRowKey : null,
            entry: entry,
            isMe: isMe,
            onTap: () => onOpenProfile(entry),
          );
        },
      ),
    ),
    SliverToBoxAdapter(
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        child: state.isLoadingMore
            ? const Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: Center(child: CircularProgressIndicator()),
              )
            : const SizedBox(height: myRankBarClearance),
      ),
    ),
  ];
}
