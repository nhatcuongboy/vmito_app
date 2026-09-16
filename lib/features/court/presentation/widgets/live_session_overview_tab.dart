import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/court/presentation/widgets/live_session_doubles_stats.dart';
import 'package:vmito_app/features/court/presentation/widgets/live_session_roster_section.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_action_bar.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_gallery.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_info_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_stat_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_stats_grid.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_status_banner.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_export_sheet.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/session_rating_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Player-facing "Tổng quan" tab. Mirrors `HostOverviewTab`'s layout (status
/// banner, gallery, info card, stats grid) via the shared overview widgets,
/// but the stats section shows the current player's own `PlayerStatistics`
/// instead of session-wide counts, and the sticky footer (when shown) is a
/// "rate the host" call to action rather than start/end session.
class LiveSessionOverviewTab extends ConsumerWidget {
  const LiveSessionOverviewTab({
    required this.session,
    required this.player,
    required this.onRefresh,
    super.key,
  });
  final Session session;
  final SessionPlayer player;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final stats = ref.watch(playerStatisticsProvider(session.id));
    final playerMatches = ref.watch(
      playerMatchHistoryProvider((sessionId: session.id, playerId: player.id)),
    );
    final rating = ref.watch(ratingEligibilityProvider(session.id));
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;
    final hasStatusBanner =
        session.status == SessionStatus.cancelled ||
        session.status == SessionStatus.finished;
    final ratingData = rating.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final showRateCta =
        session.status == SessionStatus.finished &&
        session.hostAccountId != null &&
        ratingData != null &&
        !ratingData.hasRatedHost &&
        ratingData.canRateHost;
    final roster = [
      ...session.approvedPlayers,
    ]..sort((a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)));

    final content = RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          key: const PageStorageKey('player-live-overview'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (hasStatusBanner) ...[
              SessionStatusBanner(session: session),
              const SizedBox(height: AppSpacing.md),
            ],
            if (session.galleryImages.isNotEmpty) ...[
              SessionGallery(
                images: session.galleryImages,
                onShare: () => _share(context, session),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            SessionInfoCard(
              session: session,
              showNewAddress: showNewAddress,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.playerLivePersonalStats,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            stats.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => TextButton(
                onPressed: () =>
                    ref.invalidate(playerStatisticsProvider(session.id)),
                child: Text(l10n.commonRetry),
              ),
              data: (all) {
                final own = all
                    .where((s) => s.playerId == player.id)
                    .firstOrNull;
                final winRate = own?.winRate ?? 0;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SessionStatsGrid(
                      maxWidth: constraints.maxWidth,
                      children: [
                        SessionStatCard(
                          icon: AppIcons.trophy,
                          color: Colors.blueGrey,
                          label: l10n.playerLiveMatches,
                          value: '${own?.totalMatches ?? 0}',
                        ),
                        SessionStatCard(
                          icon: AppIcons.checkCircle,
                          color: Colors.green,
                          label: l10n.playerLiveWins,
                          value: '${own?.wins ?? 0}',
                        ),
                        SessionStatCard(
                          icon: AppIcons.cancel,
                          color: Colors.red,
                          label: l10n.playerLiveLosses,
                          value: '${own?.losses ?? 0}',
                        ),
                        SessionStatCard(
                          icon: AppIcons.trendingUp,
                          color: Colors.teal,
                          label: l10n.playerLiveWinRate,
                          value: '${winRate.toStringAsFixed(0)}%',
                          progress: winRate / 100,
                        ),
                      ],
                    ),
                    if (own != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => showPlayerStatisticsExportSheet(
                            context,
                            session: session,
                            players: [own],
                            showShuttlecocks: false,
                          ),
                          icon: const Icon(AppIcons.share, size: 18),
                          label: Text(l10n.hostPlayerStatsShare),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            playerMatches.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (matches) => LiveSessionDoublesStats(
                session: session,
                player: player,
                matches: matches,
              ),
            ),
            if (session.status == SessionStatus.finished) ...[
              const SizedBox(height: AppSpacing.lg),
              rating.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => const SizedBox.shrink(),
                data: (value) {
                  if (!value.hasRatedHost) return const SizedBox.shrink();
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(l10n.playerLiveApprovedRating),
                    subtitle: Text(value.hostRating?.comment ?? ''),
                    trailing: Text('${value.hostRating?.rating ?? 0}/5'),
                  );
                },
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            LiveSessionRosterSection(
              roster: roster,
              currentPlayerId: player.id,
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );

    if (!showRateCta) return content;

    return Column(
      children: [
        Expanded(child: content),
        SessionActionBar(
          child: FilledButton.icon(
            onPressed: () => showRatingDialog(
              context,
              ref,
              sessionId: session.id,
              userId: session.hostAccountId!,
              name: session.displayHostName,
              type: 'PLAYER_TO_HOST',
            ),
            icon: const Icon(Icons.star_outline),
            label: Text(l10n.playerLiveRateHost),
          ),
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context, Session session) async {
    final box = context.findRenderObject();
    final accessCodeSuffix = session.isInternal && session.accessCode != null
        ? '?code=${session.accessCode}'
        : '';
    await SharePlus.instance.share(
      ShareParams(
        text:
            '${session.name}\nhttps://vmito.com/vi/sessions/${session.slug ?? session.id}$accessCodeSuffix',
        // iPad anchors the share sheet to the tapped rect; without it the
        // sheet throws rather than opening.
        sharePositionOrigin: box is RenderBox
            ? box.localToGlobal(Offset.zero) & box.size
            : null,
      ),
    );
  }
}

int _statusOrder(PlayerStatus status) => switch (status) {
  PlayerStatus.playing => 0,
  PlayerStatus.ready => 1,
  PlayerStatus.waiting => 2,
  PlayerStatus.finished => 3,
  PlayerStatus.inactive => 4,
};

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
