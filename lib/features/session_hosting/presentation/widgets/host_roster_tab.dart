import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class HostRosterTab extends ConsumerWidget {
  const HostRosterTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final roster = [...session.players]
      ..sort((a, b) {
        if (a.isWaiting != b.isWaiting) return a.isWaiting ? -1 : 1;
        return b.currentWaitTime.compareTo(a.currentWaitTime);
      });
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionDetailProvider(session.id).future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.hostManagePendingApprovals,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (session.pendingPlayers.isEmpty)
            Text(l10n.hostManageNoPending)
          else
            for (final player in session.pendingPlayers)
              Card(
                child: ListTile(
                  title: Text(l10n.playerName(player)),
                  subtitle: player.phone == null ? null : Text(player.phone!),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        tooltip: l10n.hostManageReject,
                        onPressed: () => controller.updateRegistration(
                          player.id,
                          approved: false,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filled(
                        tooltip: l10n.hostManageApprove,
                        onPressed: () => controller.updateRegistration(
                          player.id,
                          approved: true,
                        ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.hostManageApprovedPlayers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (roster.isEmpty)
            Text(l10n.hostManageNoPlayers)
          else
            for (final player in roster)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${player.playerNumber ?? '•'}'),
                  ),
                  title: Text(l10n.playerName(player)),
                  subtitle: Text(
                    player.isWaiting
                        ? '${_playerStatus(l10n, player.status)} · '
                              '${l10n.waitingTimeLabel}: '
                              '${Dates.waitMinutes(player.currentWaitTime, locale: locale)}'
                        : _playerStatus(l10n, player.status),
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        tooltip: player.status == PlayerStatus.inactive
                            ? l10n.hostManageCheckIn
                            : l10n.hostManageCheckOut,
                        onPressed: player.isOnCourt
                            ? null
                            : () => controller.toggleCheckIn(player.id),
                        icon: Icon(
                          player.status == PlayerStatus.inactive
                              ? Icons.how_to_reg_outlined
                              : Icons.person_off_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.hostManageRemove,
                        onPressed: player.isOnCourt
                            ? null
                            : () => controller.removePlayer(player.id),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _playerStatus(AppLocalizations l10n, PlayerStatus status) =>
      switch (status) {
        PlayerStatus.waiting => l10n.playerStatusWaiting,
        PlayerStatus.playing => l10n.playerStatusPlaying,
        PlayerStatus.finished => l10n.playerStatusFinished,
        PlayerStatus.ready => l10n.playerStatusReady,
        PlayerStatus.inactive => l10n.playerStatusInactive,
      };
}
