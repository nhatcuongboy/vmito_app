import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/court_selection_controller.dart';
import 'package:vmito_app/features/court/application/court_selection_state.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_auto_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_manual_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';

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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
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
            const _Grabber(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ).copyWith(bottom: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectionKey.preSelect
                        ? l10n.courtPreSelectNext
                        : l10n.courtSelectionTitle(court.courtNumber),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.courtSelectionDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            _MatchTypeToggle(
              matchType: state.matchType,
              onChanged: controller.setMatchType,
            ),
            TabBar(
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
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          minimumSize: const Size(0, 32),
        ),
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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final remaining = state.requiredCount - state.selectedIds.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Say what is missing rather than leaving a dead button.
            if (state.mode == CourtSelectionMode.manual && remaining > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  l10n.courtSelectRequiredPlayers(state.requiredCount),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ),
            Row(
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
          ],
        ),
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).extension<AppPalette>()!.border,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
      ),
    );
  }
}
