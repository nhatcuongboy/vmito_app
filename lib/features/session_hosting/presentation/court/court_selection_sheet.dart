import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/application/court_selection_state.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_auto_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_manual_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_grabber.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

/// Opens the assign sheet and resolves to the seats the host confirmed.
///
/// Returns null when they backed out. A full-screen modal sheet rather than a
/// dialog: the court preview plus a scrolling player grid does not fit a
/// phone-width `AlertDialog`.
Future<List<PlayerPosition>?> showCourtSelectionSheet(
  BuildContext context, {
  required String sessionId,
  required Court court,
  bool preSelect = false,
}) {
  return showModalBottomSheet<List<PlayerPosition>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CourtSelectionSheet(
      selectionKey: (
        sessionId: sessionId,
        courtId: court.id,
        preSelect: preSelect,
      ),
      court: court,
    ),
  );
}

/// "Ghép đôi — Sân N": pick a line-up by hand or let the server suggest one.
///
/// Ports `CourtPlayerSelectionModal.tsx` (1,013 lines). Mounted twice on web,
/// once for the current match and once for the pre-selected next one; here the
/// `preSelect` flag on the key does the same job.
class CourtSelectionSheet extends ConsumerWidget {
  const CourtSelectionSheet({
    required this.selectionKey,
    required this.court,
    super.key,
  });

  final CourtSelectionKey selectionKey;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(courtSelectionControllerProvider(selectionKey));
    final controller = ref.read(
      courtSelectionControllerProvider(selectionKey).notifier,
    );

    return DraggableScrollableSheet(
      expand: false,
      // Tall by default: a host assigning a court wants to see as many
      // waiting players as possible without dragging the sheet up first.
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, _) => DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const AppSheetGrabber(),
            AppSheetHeader(
              title: selectionKey.preSelect
                  ? l10n.courtPreSelectNext
                  : l10n.courtSelectionTitle(court.courtNumber),
              subtitle: state.mode == CourtSelectionMode.manual
                  ? l10n.courtSelectRequiredPlayers(state.requiredCount)
                  : l10n.courtAutoAssignDescription,
            ),
            _MatchTypeToggle(
              matchType: state.matchType,
              onChanged: controller.setMatchType,
            ),
            AppTabBar(
              onTap: (index) => controller.setMode(
                index == 0
                    ? CourtSelectionMode.manual
                    : CourtSelectionMode.auto,
              ),
              tabs: [
                _tab(AppIcons.userPlus, l10n.courtManualSelection),
                _tab(AppIcons.sparkles, l10n.courtAutoAssign),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: TabBarView(
                children: [
                  CourtSelectionManualTab(
                    selectionKey: selectionKey,
                    court: court,
                  ),
                  CourtSelectionAutoTab(
                    selectionKey: selectionKey,
                    court: court,
                  ),
                ],
              ),
            ),
            _Footer(
              state: state,
              onCancel: () => Navigator.pop(context),
              onConfirm: () =>
                  Navigator.pop(context, controller.confirmationPayload()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Icon and label side by side — `Tab(icon:, text:)` stacks them instead.
Tab _tab(IconData icon, String text) {
  return Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: AppSpacing.xs),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class _MatchTypeToggle extends StatelessWidget {
  const _MatchTypeToggle({required this.matchType, required this.onChanged});

  final MatchType matchType;
  final ValueChanged<MatchType> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: SegmentedButton<MatchType>(
        segments: [
          ButtonSegment(
            value: MatchType.doubles,
            icon: const Icon(AppIcons.clubs, size: 15),
            label: Text(l10n.courtMatchTypeDoubles),
          ),
          ButtonSegment(
            value: MatchType.singles,
            icon: const Icon(AppIcons.profile, size: 15),
            label: Text(l10n.courtMatchTypeSingles),
          ),
        ],
        selected: {matchType},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.state,
    required this.onCancel,
    required this.onConfirm,
  });

  final CourtSelectionState state;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSheetActionBar(
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              child: Text(l10n.courtCancelSelection),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: FilledButton(
              key: const ValueKey('confirm-player-selection'),
              onPressed: state.isComplete ? onConfirm : null,
              child: Text(l10n.courtConfirmMatch),
            ),
          ),
        ],
      ),
    );
  }
}
