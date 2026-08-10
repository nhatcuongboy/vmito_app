import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<void> showHostPlayerDetailSheet(
  BuildContext context, {
  required String sessionId,
  required String playerId,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _PlayerDetailSheet(
    sessionId: sessionId,
    playerId: playerId,
  ),
);

class _PlayerDetailSheet extends ConsumerWidget {
  const _PlayerDetailSheet({required this.sessionId, required this.playerId});

  final String sessionId;
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(playerDetailProvider(playerId));
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .82,
          ),
          child: detail.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => _SheetError(
              message: l10n.hostPlayerDetailError,
              onRetry: () => ref.invalidate(playerDetailProvider(playerId)),
            ),
            data: (player) => _PlayerDetailContent(
              sessionId: sessionId,
              player: player,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerDetailContent extends ConsumerWidget {
  const _PlayerDetailContent({required this.sessionId, required this.player});

  final String sessionId;
  final PlayerDetail player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = player.userId == null
        ? null
        : ref.watch(publicProfileProvider(player.userId!));
    final avatar = profile?.asData?.value.profile.image;
    return ListView(
      key: const Key('host-player-detail-sheet'),
      shrinkWrap: true,
      children: [
        Text(
          l10n.hostPlayerDetailTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage: avatar == null ? null : NetworkImage(avatar),
              child: avatar == null
                  ? Text(
                      (player.name?.trim().isNotEmpty ?? false)
                          ? player.name!.trim()[0].toUpperCase()
                          : '#${player.playerNumber}',
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.name ?? '#${player.playerNumber}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '#${player.playerNumber} · ${_status(l10n, player.status)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      player.userId == null
                          ? AppIcons.profile
                          : AppIcons.verified,
                      size: 15,
                    ),
                    label: Text(
                      player.userId == null
                          ? l10n.hostPlayerDetailGuest
                          : l10n.hostPlayerDetailMember,
                    ),
                  ),
                ],
              ),
            ),
            if (player.userId != null)
              IconButton(
                tooltip: l10n.hostPlayerDetailViewProfile,
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.pop(context);
                  unawaited(
                    router.push(AppRoutes.publicProfile(player.userId!)),
                  );
                },
                icon: const Icon(AppIcons.profile),
              ),
            IconButton(
              tooltip: l10n.hostPlayerDetailClose,
              onPressed: () => Navigator.pop(context),
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              children: [
                _DetailRow(
                  icon: AppIcons.info,
                  label: l10n.hostPlayerDetailStatus,
                  value: _status(l10n, player.status),
                ),
                if (player.gender != null)
                  _DetailRow(
                    icon: AppIcons.profile,
                    label: l10n.hostPlayerStatsGender,
                    value: _gender(l10n, player.gender!),
                  ),
                if (player.level != null)
                  _DetailRow(
                    icon: AppIcons.trophy,
                    label: l10n.hostPlayerStatsLevel,
                    value: levelShortLabel(player.level!) ?? '${player.level}',
                  ),
                if (player.phone?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: AppIcons.phone,
                    label: l10n.hostPlayerDetailPhone,
                    value: player.phone!,
                  ),
                if (player.levelDescription?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: AppIcons.notes,
                    label: l10n.hostPlayerDetailLevelDescription,
                    value: player.levelDescription!,
                  ),
                if (player.desire?.isNotEmpty ?? false)
                  _DetailRow(
                    icon: AppIcons.sessions,
                    label: l10n.hostPlayerDetailDesire,
                    value: player.desire!,
                  ),
                _DetailRow(
                  icon: AppIcons.history,
                  label: l10n.hostPlayerStatsMatches,
                  value: '${player.matchesPlayed}',
                ),
                _DetailRow(
                  icon: AppIcons.hourglass,
                  label: l10n.hostPlayerDetailCurrentWait,
                  value: l10n.hostPlayerStatsMinutes(player.currentWaitTime),
                ),
                _DetailRow(
                  icon: AppIcons.timer,
                  label: l10n.hostPlayerDetailTotalWait,
                  value: l10n.hostPlayerStatsMinutes(player.totalWaitTime),
                ),
                if (player.currentCourtName != null)
                  _DetailRow(
                    icon: AppIcons.grid,
                    label: l10n.hostPlayerDetailCurrentCourt,
                    value: player.currentCourtName!,
                  ),
              ],
            ),
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: AppSpacing.sm),
          profile.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (bundle) => Card(
              child: Column(
                children: [
                  _DetailRow(
                    icon: AppIcons.star,
                    label: l10n.hostPlayerDetailRating,
                    value:
                        '${bundle.stats.average.toStringAsFixed(1)} / 5 (${bundle.stats.total})',
                  ),
                  if (bundle.ratings.isNotEmpty)
                    ExpansionTile(
                      title: Text(l10n.hostPlayerDetailReviews),
                      children: [
                        for (final rating in bundle.ratings.take(5))
                          ListTile(
                            dense: true,
                            leading: Text('${rating.rating} ★'),
                            title: Text(rating.raterName ?? 'Vmito'),
                            subtitle: rating.comment == null
                                ? null
                                : Text(rating.comment!),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
        if (player.joinCode?.isNotEmpty ?? false) ...[
          const SizedBox(height: AppSpacing.sm),
          _JoinInfo(player: player),
        ],
        if (player.status == PlayerStatus.waiting ||
            player.status == PlayerStatus.inactive) ...[
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            key: const Key('host-player-toggle-active'),
            onPressed: () => _toggle(context, ref),
            icon: Icon(
              player.status == PlayerStatus.waiting
                  ? AppIcons.pause
                  : AppIcons.play,
            ),
            label: Text(
              player.status == PlayerStatus.waiting
                  ? l10n.hostPlayerDetailPause
                  : l10n.hostPlayerDetailContinue,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final succeeded = await ref
        .read(hostSessionManagementControllerProvider(sessionId).notifier)
        .toggleCheckIn(player.id);
    if (!succeeded || !context.mounted) return;
    ref
      ..invalidate(playerDetailProvider(player.id))
      ..invalidate(playerStatisticsProvider(sessionId));
  }
}

class _JoinInfo extends StatelessWidget {
  const _JoinInfo({required this.player});
  final PlayerDetail player;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final url =
        'https://vmito.com/$locale/player/${player.id}?code=${player.joinCode}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(
              l10n.hostPlayerDetailJoinInfo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            QrImageView(data: url, size: 150),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, url),
                    icon: const Icon(AppIcons.link),
                    label: Text(l10n.hostPlayerDetailCopyLink),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, player.joinCode!),
                    icon: const Icon(AppIcons.copy),
                    label: Text(l10n.hostPlayerDetailCopyCode),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String value) async {
    final message = AppLocalizations.of(context).hostPlayerDetailCopied;
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SheetError extends StatelessWidget {
  const _SheetError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(AppIcons.error, size: 40),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          TextButton(
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).hostPlayerStatsRetry),
          ),
        ],
      ),
    ),
  );
}

String _gender(AppLocalizations l10n, Gender gender) => switch (gender) {
  Gender.male => l10n.hostPlayerGenderMale,
  Gender.female => l10n.hostPlayerGenderFemale,
  Gender.other => l10n.hostPlayerGenderOther,
};

String _status(AppLocalizations l10n, PlayerStatus status) => switch (status) {
  PlayerStatus.waiting => l10n.playerStatusWaiting,
  PlayerStatus.playing => l10n.playerStatusPlaying,
  PlayerStatus.finished => l10n.playerStatusFinished,
  PlayerStatus.ready => l10n.playerStatusReady,
  PlayerStatus.inactive => l10n.playerStatusInactive,
};
