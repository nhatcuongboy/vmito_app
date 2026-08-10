import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_repeat_warning.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_pair_stats.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_search_field.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_select_grid.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// Pick the line-up by hand: tap a seat, tap a player.
class CourtSelectionManualTab extends ConsumerWidget {
  const CourtSelectionManualTab({
    required this.selectionKey,
    required this.court,
    super.key,
  });

  final CourtSelectionKey selectionKey;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(courtSelectionControllerProvider(selectionKey));
    final controller = ref.read(
      courtSelectionControllerProvider(selectionKey).notifier,
    );

    final seated = controller.seatedPlayers;
    final visible = controller.visiblePlayers;
    final selectedIds = state.selectedIds.toSet();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      children: [
        BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: state.matchType,
          selection: seated,
          activeSlot: state.activeSlot,
          onSlotTap: controller.selectSlot,
          overlays: [
            // Warns while the host is still choosing, which is the only moment
            // the warning can change anything.
            CourtSelectionRepeatWarning(
              sessionId: selectionKey.sessionId,
              court: court,
              seats: seated,
              matchType: state.matchType,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        MatchPairStats(seats: seated, matchType: state.matchType),
        const SizedBox(height: AppSpacing.md),
        PlayerSearchField(onChanged: controller.setSearch),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.courtAvailablePlayers,
          style: theme.textTheme.labelLarge?.copyWith(
            color: palette.mutedForeground,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              // Two different empty states: nobody is waiting at all, versus
              // the search matched nothing.
              controller.waitingPlayers.isEmpty
                  ? l10n.courtNoPlayersWaiting
                  : l10n.courtNoPlayersFound,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          )
        else
          PlayerSelectGrid(
            players: visible,
            selectedIds: selectedIds,
            onPlayerTap: (player) => controller.togglePlayer(player.id),
          ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}
