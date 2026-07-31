import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/presentation/widgets/court_tile.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_selection_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class HostCourtCard extends ConsumerWidget {
  const HostCourtCard({required this.session, required this.court, super.key});

  final Session session;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    final canAssign = session.status.isLive && !court.isPlaying;
    final hasPlayers = court.currentPlayers.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CourtTile(court: court),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (canAssign && !hasPlayers)
                  FilledButton.tonalIcon(
                    key: ValueKey('assign-${court.id}'),
                    onPressed: () async {
                      final players = await showDialog<List<String>>(
                        context: context,
                        builder: (_) => PlayerSelectionDialog(
                          players: session.players
                              .where(
                                (player) =>
                                    player.status == PlayerStatus.waiting,
                              )
                              .toList(),
                        ),
                      );
                      if (players != null) {
                        await controller.selectPlayers(court.id, players);
                      }
                    },
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(l10n.hostManageAssign),
                  ),
                if (canAssign && hasPlayers)
                  OutlinedButton(
                    onPressed: () => controller.deselectPlayers(court.id),
                    child: Text(l10n.hostManageClearCourt),
                  ),
                if (court.status == CourtStatus.ready)
                  FilledButton.icon(
                    key: ValueKey('start-${court.id}'),
                    onPressed: () => controller.startMatch(court.id),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.hostManageStartMatch),
                  ),
                if (court.isPlaying)
                  FilledButton.icon(
                    key: ValueKey('end-${court.id}'),
                    onPressed: () => controller.endMatch(court.id),
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(l10n.hostManageEndMatch),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
