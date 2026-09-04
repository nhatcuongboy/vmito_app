import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/color_parsing.dart';
import 'package:vmito_app/features/court/application/court_display_mode_controller.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_announce_button.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_repeat_warning_button.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_result_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/pre_select_preview_sheet.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_actions.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_card_header.dart';
import 'package:vmito_app/shared/models/court.dart';

/// One court on the host's board: status header, the court itself, actions.
///
/// Ports `vmito-fe/src/components/session/CourtCard.tsx`.
class HostCourtCard extends ConsumerWidget {
  const HostCourtCard({required this.session, required this.court, super.key});

  final Session session;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(hostCourtActionsControllerProvider(session.id));
    final controller = ref.read(
      hostCourtActionsControllerProvider(session.id).notifier,
    );
    final displayMode = ref.watch(courtDisplayModeControllerProvider);
    final shadowColor = Theme.of(context).shadowColor;

    return DecoratedBox(
      key: ValueKey('host-court-card-surface-${court.id}'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HostCourtCardHeader(court: court),
            BadmintonCourtView(
              court: court,
              preSelectedPlayers: session.preSelectedPlayersFor(court),
              mode: CourtViewMode.manage,
              displayMode: displayMode,
              matchType: court.matchTypeOr(session.defaultMatchType),
              courtColor: parseHexColor(session.courtColor),
              overlays: [
                // Nothing to announce on an empty court.
                if (court.currentPlayers.isNotEmpty)
                  CourtAnnounceButton(
                    court: court,
                    players: court.currentPlayers,
                  ),
                if (court.currentPlayers.isNotEmpty)
                  CourtRepeatWarningButton(session: session, court: court),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: HostCourtActions(
                court: court,
                isSessionLive: session.status.isLive,
                waitingCount: session.waitingQueue.length,
                isBusy: actions.isBusy(court.id),
                onAssign: () => _assign(context, controller),
                onClear: () => controller.deselectPlayers(court.id),
                onStart: () => controller.startMatch(court.id),
                onPreSelect: () => _assign(
                  context,
                  controller,
                  preSelect: true,
                ),
                onViewNextMatch: () => _viewNextMatch(context, controller),
                onEnd: () => _endMatch(context, controller),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the assign sheet, then sends whatever the host confirmed.
  ///
  /// The same sheet books the *next* match when [preSelect] is set — exactly
  /// as the web mounts its modal twice.
  Future<void> _assign(
    BuildContext context,
    HostCourtActionsController controller, {
    bool preSelect = false,
  }) async {
    final seats = await showCourtSelectionSheet(
      context,
      sessionId: session.id,
      court: court,
      preSelect: preSelect,
    );
    if (seats == null || seats.isEmpty) return;
    await (preSelect
        ? controller.preSelect(court.id, seats)
        : controller.selectPlayers(court.id, seats));
  }

  Future<void> _viewNextMatch(
    BuildContext context,
    HostCourtActionsController controller,
  ) async {
    final action = await showPreSelectPreviewSheet(
      context,
      session: session,
      court: court,
    );
    if (action == PreSelectPreviewAction.cancelPreSelection) {
      await controller.cancelPreSelect(court.id);
    }
  }

  /// Collects the score first, then ends the match.
  ///
  /// Closing the sheet aborts: ending is irreversible and the host may have
  /// tapped it on the wrong court.
  Future<void> _endMatch(
    BuildContext context,
    HostCourtActionsController controller,
  ) async {
    final result = await showMatchResultSheet(
      context,
      session: session,
      court: court,
    );
    if (result == null) return;
    await controller.endMatch(court.id, result);
  }
}
