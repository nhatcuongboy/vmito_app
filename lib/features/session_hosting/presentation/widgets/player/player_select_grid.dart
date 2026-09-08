import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_select_card.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// A responsive grid of players.
///
/// Serves both the assign sheet and the waiting list at the bottom of the
/// courts tab — the second is the same grid with nothing selectable.
///
/// Not scrollable itself: callers embed it in their own scroll view — the
/// assign sheet scrolls just this grid, keeping the court preview fixed.
class PlayerSelectGrid extends StatelessWidget {
  const PlayerSelectGrid({
    required this.players,
    this.selectedIds = const {},
    this.updateWaitTime = false,
    this.onPlayerTap,
    super.key,
  });

  final List<SessionPlayer> players;
  final Set<String> selectedIds;
  final bool updateWaitTime;
  final ValueChanged<SessionPlayer>? onPlayerTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on a phone, more once there is room. The card needs
        // ~150 px before the name starts truncating.
        final columns = (constraints.maxWidth / 175).floor().clamp(2, 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            mainAxisExtent: 100,
          ),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index];
            return PlayerSelectCard(
              key: ValueKey('player-card-${player.id}'),
              player: player,
              isSelected: selectedIds.contains(player.id),
              updateWaitTime: updateWaitTime,
              onTap: onPlayerTap == null ? null : () => onPlayerTap!(player),
            );
          },
        );
      },
    );
  }
}
