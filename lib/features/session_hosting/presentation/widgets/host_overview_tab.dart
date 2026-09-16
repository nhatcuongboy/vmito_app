import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_action_bar.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_gallery.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_info_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_stat_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_stats_grid.dart';
import 'package:vmito_app/features/session/presentation/widgets/overview/session_status_banner.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_session_action_buttons.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_section.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Mobile port of the host web app's `SessionOverviewTab`.
class HostOverviewTab extends ConsumerWidget {
  const HostOverviewTab({
    required this.session,
    this.onEdit,
    super.key,
  });

  final Session session;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final players = session.approvedPlayers;
    final capacity = session.capacity;
    final waiting = players
        .where((player) => player.status == PlayerStatus.waiting)
        .length;
    final playing = players
        .where((player) => player.status == PlayerStatus.playing)
        .length;
    final ready = players
        .where((player) => player.status == PlayerStatus.ready)
        .length;
    final male = players.where((player) => player.gender == Gender.male).length;
    final female = players
        .where((player) => player.gender == Gender.female)
        .length;
    final images = session.galleryImages;
    final showNewAddress = ref
        .watch(locationPreferencesControllerProvider)
        .showNewAddress;

    final showStartButton = session.status == SessionStatus.preparing;
    final showEndButton = session.status == SessionStatus.inProgress;
    final showBottomBar = showStartButton || showEndButton;
    final hasStatusBanner =
        session.status == SessionStatus.cancelled ||
        session.status == SessionStatus.finished;

    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(sessionDetailProvider(session.id))
          ..invalidate(playerStatisticsProvider(session.id));
        await Future.wait([
          ref.read(sessionDetailProvider(session.id).future),
          ref.read(playerStatisticsProvider(session.id).future),
        ]);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                children: [
                  if (hasStatusBanner) ...[
                    SessionStatusBanner(session: session),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (images.isNotEmpty) ...[
                    SessionGallery(
                      images: images,
                      onShare: () => _share(context, session),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  SessionInfoCard(
                    session: session,
                    onEdit: onEdit,
                    showNewAddress: showNewAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.sessionOverviewStatsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SessionStatsGrid(
                    maxWidth: constraints.maxWidth,
                    children: [
                      SessionStatCard(
                        icon: AppIcons.clubs,
                        color: Colors.green,
                        label: l10n.sessionPlayersTitle,
                        value: '${players.length}/$capacity',
                        detail: male + female == 0
                            ? null
                            : l10n.sessionOverviewGenderBreakdown(male, female),
                        progress: capacity == 0
                            ? null
                            : players.length / capacity,
                      ),
                      SessionStatCard(
                        icon: AppIcons.hourglass,
                        color: Colors.orange,
                        label: l10n.sessionOverviewStatWaiting,
                        value: '$waiting',
                      ),
                      SessionStatCard(
                        icon: AppIcons.trophy,
                        color: Colors.green,
                        label: l10n.courtStatusPlaying,
                        value: '$playing',
                      ),
                      SessionStatCard(
                        icon: AppIcons.checkCircle,
                        color: Colors.teal,
                        label: l10n.courtStatusReady,
                        value: '$ready',
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PlayerStatisticsSection(session: session),
                ],
              ),
            ),
          );

          if (!showBottomBar) return content;

          final button = showStartButton
              ? HostStartSessionButton(sessionId: session.id)
              : HostEndSessionButton(sessionId: session.id);

          return Column(
            children: [
              Expanded(child: content),
              SessionActionBar(child: button),
            ],
          );
        },
      ),
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
