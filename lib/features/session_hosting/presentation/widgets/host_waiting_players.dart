import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player/player_select_grid.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Who is free to be put on a court, longest wait first.
///
/// Read-only: the host assigns from a court's own sheet, so tapping a card
/// here would have no court to assign to.
class HostWaitingPlayers extends StatelessWidget {
  const HostWaitingPlayers({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final waiting = session.waitingQueue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${l10n.courtWaitingPlayers} (${waiting.length})',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (waiting.isEmpty)
          Text(
            l10n.courtNoPlayersWaiting,
            style: theme.textTheme.bodySmall?.copyWith(
              color: palette.mutedForeground,
            ),
          )
        else
          PlayerSelectGrid(
            players: waiting,
            updateWaitTime: session.status.isLive,
          ),
      ],
    );
  }
}
