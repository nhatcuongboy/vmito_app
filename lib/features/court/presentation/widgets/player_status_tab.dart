import 'package:flutter/material.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/color_parsing.dart';
import 'package:vmito_app/features/court/domain/player_live_session.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/match_elapsed_badge.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// The "Trạng thái" tab of the player-facing "Vào sân" screen.
///
/// Ports `vmito-fe/src/components/session/PlayerStatusTab.tsx`, adapted into
/// three separate `Card`s (status, court, summary) rather than the web's one
/// monolithic bordered box — matching how every other tab in this feature is
/// composed (see `PlayerLivePaymentTab`).
class PlayerStatusTab extends StatelessWidget {
  const PlayerStatusTab({
    required this.projection,
    required this.onRefresh,
    super.key,
  });

  final PlayerLiveSession projection;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final player = projection.player;
    final court = projection.currentCourt;
    final courtPlayers = projection.courtPlayers;
    final showCourt = court != null && courtPlayers.isNotEmpty;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey('player-live-status'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _StatusHeaderCard(player: player),
          if (showCourt) ...[
            const SizedBox(height: AppSpacing.md),
            _CourtCard(projection: projection, court: court),
          ] else if (player.status == PlayerStatus.waiting) ...[
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Text(
                l10n.playerLiveNoCurrentCourt,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _SummaryCard(projection: projection),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _StatusHeaderCard extends StatelessWidget {
  const _StatusHeaderCard({required this.player});
  final SessionPlayer player;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final (icon, color, title, description) = switch (player.status) {
      PlayerStatus.playing => (
        AppIcons.checkCircle,
        palette.success,
        l10n.playerLiveStatusPlayingTitle,
        l10n.playerLiveStatusPlayingDescription,
      ),
      PlayerStatus.ready => (
        AppIcons.clock,
        palette.warning,
        l10n.playerLiveStatusReadyTitle,
        l10n.playerLiveStatusReadyDescription,
      ),
      PlayerStatus.waiting => (
        AppIcons.clock,
        palette.info,
        l10n.playerLiveStatusWaitingTitle,
        l10n.playerLiveStatusWaitingDescription,
      ),
      PlayerStatus.finished || PlayerStatus.inactive => (
        AppIcons.checkCircle,
        palette.mutedForeground,
        l10n.playerLiveStatusFinishedTitle,
        l10n.playerLiveStatusFinishedDescription,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(
              l10n.playerName(player),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourtCard extends StatelessWidget {
  const _CourtCard({required this.projection, required this.court});
  final PlayerLiveSession projection;
  final Court court;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final startTime = projection.currentMatch?.startTime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.courtName(court),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: palette.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (startTime != null) MatchElapsedBadge(startTime: startTime),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BadmintonCourtView(
              court: court,
              highlightedPlayerId: projection.player.id,
              preSelectedPlayers: projection.session.preSelectedPlayersFor(
                court,
              ),
              courtColor: parseHexColor(projection.session.courtColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.playerLiveCourtHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            if (projection.partners.isNotEmpty ||
                projection.opponents.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              _PairingBox(
                partners: projection.partners,
                opponents: projection.opponents,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PairingBox extends StatelessWidget {
  const _PairingBox({required this.partners, required this.opponents});
  final List<SessionPlayer> partners;
  final List<SessionPlayer> opponents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const orangeBorder = Color(0xFFF97316);
    final orangeBackground = isDark
        ? const Color(0xFF7C2D12)
        : const Color(0xFFFFF7ED);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.brandSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          if (partners.isNotEmpty)
            _PairingGroup(
              icon: AppIcons.handshake,
              label: l10n.playerLivePartner,
              labelColor: palette.success,
              chipBackground: theme.colorScheme.primary.withValues(
                alpha: isDark ? 0.24 : 0.12,
              ),
              chipForeground: palette.success,
              players: partners,
            ),
          if (partners.isNotEmpty && opponents.isNotEmpty)
            const SizedBox(height: AppSpacing.sm),
          if (opponents.isNotEmpty)
            _PairingGroup(
              icon: AppIcons.swords,
              label: l10n.playerLiveOpponents,
              labelColor: orangeBorder,
              chipBackground: orangeBackground,
              chipForeground: orangeBorder,
              players: opponents,
            ),
        ],
      ),
    );
  }
}

class _PairingGroup extends StatelessWidget {
  const _PairingGroup({
    required this.icon,
    required this.label,
    required this.labelColor,
    required this.chipBackground,
    required this.chipForeground,
    required this.players,
  });

  final IconData icon;
  final String label;
  final Color labelColor;
  final Color chipBackground;
  final Color chipForeground;
  final List<SessionPlayer> players;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: labelColor),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final player in players)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: chipBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  '#${player.playerNumber ?? '–'} ${player.displayName ?? l10n.playerFallback}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: chipForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.projection});
  final PlayerLiveSession projection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final l10n = AppLocalizations.of(context);
    final player = projection.player;
    final isPlaying = player.status == PlayerStatus.playing;
    final isWaiting = player.status == PlayerStatus.waiting;
    final elapsed = projection.currentMatch?.startTime == null
        ? null
        : DateTime.now()
              .difference(projection.currentMatch!.startTime!)
              .inMinutes;

    final (timeValue, timeLabel) = isPlaying && elapsed != null
        ? (l10n.playerLiveMinutes(elapsed), l10n.playerLivePlayingTime)
        : (
            l10n.playerLiveMinutes(player.currentWaitTime),
            l10n.playerLiveWaitTime,
          );
    final (countValue, countLabel) = projection.waitingPosition != null
        ? ('#${projection.waitingPosition}', l10n.playerLiveQueuePosition)
        : ('${player.matchesPlayed}', l10n.playerLiveMatches);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: AppIcons.clock,
                    value: timeValue,
                    label: timeLabel,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatTile(
                    icon: AppIcons.users,
                    value: countValue,
                    label: countLabel,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Text(
              isPlaying
                  ? l10n.playerLiveFooterPlaying
                  : isWaiting
                  ? l10n.playerLiveFooterWaiting
                  : l10n.playerLiveFooterFinished,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: palette.mutedForeground),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
