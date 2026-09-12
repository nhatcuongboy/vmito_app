import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/celebration/confetti_burst.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/celebration/leaderboard_celebration_card.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_visuals.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Congratulates the signed-in user on a top-3 finish. Gated by
/// `LeaderboardCelebrationController` so it fires once per period.
Future<void> showLeaderboardCelebration(
  BuildContext context, {
  required LeaderboardEntry entry,
}) {
  final l10n = AppLocalizations.of(context);
  unawaited(
    SemanticsService.sendAnnouncement(
      View.of(context),
      '${l10n.leaderboardCelebrationTitle} '
      '${l10n.leaderboardCelebrationRank(entry.rank)}',
      Directionality.of(context),
    ),
  );
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (context) => _Celebration(entry: entry),
  );
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Center(child: LeaderboardCelebrationCard(entry: entry)),
      // Above the card, matching the web overlay's z-order.
      Positioned.fill(
        child: ConfettiBurst(
          colors: medalConfettiColors(Theme.of(context).brightness),
        ),
      ),
    ],
  );
}
