import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

/// The host's buttons for one court.
///
/// Ports the button matrix in `vmito-fe/src/components/session/CourtCard.tsx`.
/// Every button is gated on a live session — a court on a session that has not
/// started, or has ended, is read-only.
class HostCourtActions extends StatelessWidget {
  const HostCourtActions({
    required this.court,
    required this.isSessionLive,
    required this.waitingCount,
    required this.isBusy,
    required this.onAssign,
    required this.onClear,
    required this.onStart,
    required this.onPreSelect,
    required this.onViewNextMatch,
    required this.onEnd,
    super.key,
  });

  final Court court;
  final bool isSessionLive;

  /// How many players are free to be put on a court. Doubles needs four, and
  /// the web disables assignment below that rather than letting the host open
  /// a sheet they cannot complete.
  final int waitingCount;

  final bool isBusy;

  final VoidCallback onAssign;
  final VoidCallback onClear;
  final VoidCallback onStart;
  final VoidCallback onPreSelect;
  final VoidCallback onViewNextMatch;
  final VoidCallback onEnd;

  static const _minimumToAssign = 4;

  @override
  Widget build(BuildContext context) {
    if (!isSessionLive) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;

    final hasPlayers = court.currentPlayers.isNotEmpty;
    final isRunning = court.currentMatchId != null;
    final isReady = court.status == CourtStatus.ready;
    // A running match is anything with a match id that has moved past READY.
    final isPlaying = isRunning && !isReady;
    final hasEnoughWaiting = waitingCount >= _minimumToAssign;

    final buttons = <Widget>[
      if (!hasPlayers && !isRunning)
        FilledButton.tonalIcon(
          key: ValueKey('assign-${court.id}'),
          onPressed: isBusy || !hasEnoughWaiting ? null : onAssign,
          icon: const Icon(AppIcons.shuffle, size: 18),
          label: Text(l10n.courtAssignPlayers),
        ),
      if (isReady && !isRunning)
        FilledButton.icon(
          key: ValueKey('start-${court.id}'),
          onPressed: isBusy ? null : onStart,
          icon: const Icon(AppIcons.play, size: 18),
          label: Text(l10n.courtStartMatch),
        ),
      if (isReady && hasPlayers)
        OutlinedButton.icon(
          key: ValueKey('clear-${court.id}'),
          onPressed: isBusy ? null : onClear,
          icon: const Icon(AppIcons.close, size: 18),
          label: Text(l10n.courtCancelSelection),
        ),
      if (isPlaying && !court.hasPreSelection)
        OutlinedButton.icon(
          key: ValueKey('pre-select-${court.id}'),
          onPressed: isBusy || !hasEnoughWaiting ? null : onPreSelect,
          icon: const Icon(AppIcons.add, size: 18),
          label: Text(l10n.courtPreSelectNext),
        ),
      if (isPlaying && court.hasPreSelection)
        OutlinedButton.icon(
          key: ValueKey('view-next-${court.id}'),
          onPressed: isBusy ? null : onViewNextMatch,
          icon: const Icon(AppIcons.eye, size: 18),
          label: Text(l10n.courtViewNextMatch),
        ),
      if (isPlaying)
        FilledButton.icon(
          key: ValueKey('end-${court.id}'),
          onPressed: isBusy ? null : onEnd,
          icon: const Icon(AppIcons.stop, size: 18),
          label: Text(l10n.courtEndMatch),
        ),
    ];

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Say why the button is dead rather than leaving the host guessing.
        if (!hasPlayers && !isRunning && !hasEnoughWaiting)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              l10n.courtNeedMorePlayers(_minimumToAssign - waitingCount),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: palette.mutedForeground),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: buttons,
        ),
      ],
    );
  }
}
