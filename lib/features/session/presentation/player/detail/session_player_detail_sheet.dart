import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

Future<void> showSessionPlayerDetailSheet(
  BuildContext context, {
  required SessionPlayer player,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _SessionPlayerDetailSheet(player: player),
);

class _SessionPlayerDetailSheet extends ConsumerWidget {
  const _SessionPlayerDetailSheet({required this.player});

  final SessionPlayer player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(playerDetailProvider(player.id));
    final profile = player.userId == null
        ? null
        : ref.watch(publicProfileProvider(player.userId!));
    final profileImage = profile?.asData?.value.profile.image;
    final image = profileImage ?? player.userImage;
    final l10n = AppLocalizations.of(context);

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
            loading: () => _PlayerSummary(
              player: player,
              image: image,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: LinearProgressIndicator(),
              ),
            ),
            error: (_, _) => _PlayerSummary(
              player: player,
              image: image,
              child: Text(l10n.hostPlayerDetailError),
            ),
            data: (value) => _PlayerDetailContent(
              player: player,
              detail: value,
              image: image,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerSummary extends StatelessWidget {
  const _PlayerSummary({
    required this.player,
    required this.image,
    required this.child,
  });

  final SessionPlayer player;
  final String? image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = l10n.playerName(player);
    return ListView(
      key: const Key('session-player-detail-sheet'),
      shrinkWrap: true,
      children: [
        Text(
          l10n.hostPlayerDetailTitle,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        _Header(player: player, name: name, image: image),
        const SizedBox(height: AppSpacing.md),
        child,
        if (player.level != null)
          _DetailRow(
            icon: AppIcons.shield,
            label: l10n.hostPlayerStatsLevel,
            value: levelShortLabel(player.level!) ?? '${player.level}',
          ),
        if (player.gender != null)
          _DetailRow(
            icon: AppIcons.profile,
            label: l10n.hostPlayerStatsGender,
            value: _gender(l10n, player.gender!),
          ),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
          label: Text(l10n.hostPlayerDetailClose),
        ),
      ],
    );
  }
}

class _PlayerDetailContent extends StatelessWidget {
  const _PlayerDetailContent({
    required this.player,
    required this.detail,
    required this.image,
  });

  final SessionPlayer player;
  final PlayerDetail detail;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      key: const Key('session-player-detail-sheet'),
      shrinkWrap: true,
      children: [
        Text(
          l10n.hostPlayerDetailTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        _Header(
          player: player,
          name: detail.name ?? l10n.playerName(player),
          image: image,
          userId: player.userId,
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
                  value: _status(l10n, detail.status),
                ),
                if (detail.gender != null)
                  _DetailRow(
                    icon: AppIcons.profile,
                    label: l10n.hostPlayerStatsGender,
                    value: _gender(l10n, detail.gender!),
                  ),
                if (detail.level != null)
                  _DetailRow(
                    icon: AppIcons.shield,
                    label: l10n.hostPlayerStatsLevel,
                    value: levelShortLabel(detail.level!) ?? '${detail.level}',
                  ),
                if (detail.levelDescription?.trim().isNotEmpty ?? false)
                  _DetailRow(
                    icon: AppIcons.notes,
                    label: l10n.hostPlayerDetailLevelDescription,
                    value: detail.levelDescription!,
                  ),
                if (detail.desire?.trim().isNotEmpty ?? false)
                  _DetailRow(
                    icon: AppIcons.sessions,
                    label: l10n.hostPlayerDetailDesire,
                    value: detail.desire!,
                  ),
                _DetailRow(
                  icon: AppIcons.history,
                  label: l10n.hostPlayerStatsMatches,
                  value: '${detail.matchesPlayed}',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
          label: Text(l10n.hostPlayerDetailClose),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.player,
    required this.name,
    required this.image,
    this.userId,
  });

  final SessionPlayer player;
  final String name;
  final String? image;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        UserAvatar(
          name: name,
          gender: player.gender?.name,
          status: player.status.name,
          imageUrl: image,
          size: 60,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: theme.textTheme.titleLarge),
              Text(
                '#${player.playerNumber ?? '-'} · ${l10n.hostPlayerDetailMember}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (userId != null)
          IconButton(
            tooltip: l10n.hostPlayerDetailViewProfile,
            icon: const Icon(AppIcons.profile),
            onPressed: () {
              Navigator.pop(context);
              unawaited(
                GoRouter.of(context).push(AppRoutes.publicProfile(userId!)),
              );
            },
          ),
      ],
    );
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

String _status(AppLocalizations l10n, PlayerStatus status) => switch (status) {
  PlayerStatus.waiting => l10n.hostPlayerDetailStatusWaiting,
  PlayerStatus.playing => l10n.hostPlayerDetailStatusPlaying,
  PlayerStatus.finished => l10n.hostPlayerDetailStatusFinished,
  PlayerStatus.ready => l10n.hostPlayerDetailStatusReady,
  PlayerStatus.inactive => l10n.hostPlayerDetailStatusInactive,
};

String _gender(AppLocalizations l10n, Gender gender) => switch (gender) {
  Gender.male => l10n.genderMale,
  Gender.female => l10n.genderFemale,
  Gender.other => l10n.genderOther,
};
