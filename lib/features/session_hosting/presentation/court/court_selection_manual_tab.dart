import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/color_parsing.dart';
import 'package:vmito_app/features/court/application/court_display_mode_controller.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
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
    final displayMode = ref.watch(courtDisplayModeControllerProvider);
    final session = ref
        .watch(sessionDetailProvider(selectionKey.sessionId))
        .asData
        ?.value;
    final courtColor = parseHexColor(session?.courtColor);
    final state = ref.watch(courtSelectionControllerProvider(selectionKey));
    final controller = ref.read(
      courtSelectionControllerProvider(selectionKey).notifier,
    );

    final seated = controller.seatedPlayers;
    final visible = controller.visiblePlayers;
    final selectedIds = state.selectedIds.toSet();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BadmintonCourtView(
                court: court.copyWith(status: CourtStatus.inUse),
                courtColor: courtColor,
                mode: CourtViewMode.selection,
                displayMode: displayMode,
                matchType: state.matchType,
                selection: seated,
                activeSlot: state.activeSlot,
                onSlotTap: controller.selectSlot,
                overlays: [
                  // Warns while the host is still choosing, which is the only
                  // moment the warning can change anything.
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
              Row(
                children: [
                  Text(
                    l10n.courtAvailablePlayers,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: PlayerSearchField(
                      onChanged: controller.setSearch,
                      compact: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
        // Only this part scrolls: the court preview stays put, so the host
        // never loses sight of the seats they are filling.
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Text(
                      // Two different empty states: nobody is waiting at all,
                      // versus the search matched nothing.
                      controller.waitingPlayers.isEmpty
                          ? l10n.courtNoPlayersWaiting
                          : l10n.courtNoPlayersFound,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: palette.mutedForeground,
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: PlayerSelectGrid(
                    players: visible,
                    selectedIds: selectedIds,
                    onPlayerTap: (player) => controller.togglePlayer(player.id),
                  ),
                ),
        ),
      ],
    );
  }
}
