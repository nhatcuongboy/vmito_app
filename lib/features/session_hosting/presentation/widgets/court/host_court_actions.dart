import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_state.dart';
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
    required this.activeAction,
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
  final HostCourtAction? activeAction;

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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    final hasPlayers = court.currentPlayers.isNotEmpty;
    final isRunning = court.currentMatchId != null;
    final isReady = court.status == CourtStatus.ready;
    // A running match is anything with a match id that has moved past READY.
    final isPlaying = isRunning && !isReady;
    final hasEnoughWaiting = waitingCount >= _minimumToAssign;

    final buttons = <Widget>[
      if (!hasPlayers && !isRunning)
        FilledButton.icon(
          key: ValueKey('assign-${court.id}'),
          style: _solid(palette.success),
          onPressed: isBusy || !hasEnoughWaiting ? null : onAssign,
          icon: _actionIcon(
            AppIcons.shuffle,
            isLoading: activeAction == HostCourtAction.assign,
            loadingColor: Colors.white,
          ),
          label: Text(l10n.courtAssignPlayers),
        ),
      // Thay đổi thứ tự: nút "Hủy" trước, nút "Bắt đầu" sau
      if (isReady && hasPlayers)
        OutlinedButton.icon(
          key: ValueKey('clear-${court.id}'),
          style: _outline(theme.colorScheme.error),
          onPressed: isBusy ? null : onClear,
          icon: _actionIcon(
            AppIcons.close,
            isLoading: activeAction == HostCourtAction.clear,
            loadingColor: theme.colorScheme.error,
          ),
          label: Text(l10n.courtCancelSelection),
        ),
      if (isReady && !isRunning)
        FilledButton.icon(
          key: ValueKey('start-${court.id}'),
          style: _solid(palette.success),
          onPressed: isBusy ? null : onStart,
          icon: _actionIcon(
            AppIcons.play,
            isLoading: activeAction == HostCourtAction.start,
            loadingColor: Colors.white,
          ),
          label: Text(l10n.courtStartMatch),
        ),
      if (isPlaying && !court.hasPreSelection)
        OutlinedButton.icon(
          key: ValueKey('pre-select-${court.id}'),
          style: _outline(palette.success),
          onPressed: isBusy || !hasEnoughWaiting ? null : onPreSelect,
          icon: _actionIcon(
            AppIcons.userPlus,
            isLoading: activeAction == HostCourtAction.preSelect,
            loadingColor: palette.success,
          ),
          label: Text(l10n.courtPreSelectShort),
        ),
      if (isPlaying && court.hasPreSelection)
        OutlinedButton.icon(
          key: ValueKey('view-next-${court.id}'),
          style: _outline(_purple),
          onPressed: isBusy ? null : onViewNextMatch,
          icon: _actionIcon(
            AppIcons.eye,
            isLoading: activeAction == HostCourtAction.cancelPreSelect,
            loadingColor: _purple,
          ),
          label: Text(l10n.courtViewNextMatch),
        ),
      if (isPlaying)
        FilledButton.icon(
          key: ValueKey('end-${court.id}'),
          style: _solid(theme.colorScheme.error),
          onPressed: isBusy ? null : onEnd,
          icon: _actionIcon(
            AppIcons.stop,
            isLoading: activeAction == HostCourtAction.end,
            loadingColor: Colors.white,
          ),
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
        Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ],
    );
  }
}

Widget _actionIcon(
  IconData icon, {
  required bool isLoading,
  required Color loadingColor,
}) => isLoading
    ? SizedBox.square(
        dimension: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: loadingColor),
      )
    : Icon(icon, size: 16);

/// Web's `colorPalette="green"`/`"red"` solid buttons (size="sm").
ButtonStyle _solid(Color color) => FilledButton.styleFrom(
  backgroundColor: color,
  foregroundColor: Colors.white,
  visualDensity: VisualDensity.compact,
  minimumSize: const Size(0, AppSizes.minTapTarget),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
);

/// Web's `colorPalette="..."` `variant="outline"` buttons (size="sm").
ButtonStyle _outline(Color color) => OutlinedButton.styleFrom(
  foregroundColor: color,
  side: BorderSide(color: color),
  visualDensity: VisualDensity.compact,
  minimumSize: const Size(0, AppSizes.minTapTarget),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
  ),
);

/// "Xem trận tiếp theo" — Chakra's `purple.500`, matched to the same shade
/// used for the "other" gender badge on the court.
const _purple = Color(0xFF805AD5);
