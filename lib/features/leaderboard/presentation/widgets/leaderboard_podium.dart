import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_podium_card.dart';

/// Above this text scale three cards across stops fitting, so the podium
/// becomes a plain vertical list in rank order.
const _stackedTextScale = 1.3;

class LeaderboardPodium extends StatelessWidget {
  const LeaderboardPodium({
    required this.entries,
    required this.period,
    required this.currentUserId,
    required this.onTap,
    super.key,
  });

  final List<LeaderboardEntry> entries;
  final LeaderboardPeriod period;
  final String? currentUserId;
  final ValueChanged<LeaderboardEntry> onTap;

  bool _isMe(LeaderboardEntry entry) =>
      currentUserId != null && entry.user.id == currentUserId;

  Widget _card(LeaderboardEntry entry) => LeaderboardPodiumCard(
    entry: entry,
    period: period,
    isMe: _isMe(entry),
    onTap: () => onTap(entry),
  );

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(1) > _stackedTextScale) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final entry in entries) ...[
            _card(entry),
            if (entry != entries.last) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    // Display order 2-1-3, with the champion given the widest column, matching
    // `vmito-fe/LeaderboardContent.tsx`'s PODIUM_ORDER.
    final ordered = <LeaderboardEntry>[
      if (entries.length > 1) entries[1],
      entries[0],
      if (entries.length > 2) entries[2],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var index = 0; index < ordered.length; index++) ...[
          // Bottom-aligned, so the champion's greater height *is* the
          // pedestal step; no top padding can add to it.
          Expanded(
            flex: ordered[index].rank == 1 ? 40 : 30,
            child: _card(ordered[index]),
          ),
          if (index != ordered.length - 1) const SizedBox(width: AppSpacing.sm),
        ],
      ],
    );
  }
}
