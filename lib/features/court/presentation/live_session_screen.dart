import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/color_parsing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/court/application/match_elapsed_provider.dart';
import 'package:vmito_app/features/court/domain/player_live_session.dart';
import 'package:vmito_app/features/court/presentation/player_live_payment_tab.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/player_statistics_export_sheet.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/session_rating_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class LiveSessionScreen extends ConsumerStatefulWidget {
  const LiveSessionScreen({required this.sessionId, super.key});
  final String sessionId;
  @override
  ConsumerState<LiveSessionScreen> createState() => _LiveSessionScreenState();
}

class _LiveSessionScreenState extends ConsumerState<LiveSessionScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  final _visited = <int>{0};
  Timer? _poll;
  StreamSubscription<SocketEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    _events = ref.read(socketClientProvider).events.listen(_showEventFeedback);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    unawaited(_events?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLoaded();
      _startPolling();
    } else {
      _poll?.cancel();
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(minutes: 3), (_) => _refreshLoaded());
  }

  void _refreshLoaded() {
    ref
      ..invalidate(sessionDetailProvider(widget.sessionId))
      ..invalidate(playerStatisticsProvider(widget.sessionId))
      ..invalidate(ratingEligibilityProvider(widget.sessionId));
    if (_visited.contains(4)) {
      ref.invalidate(playerSessionPaymentsProvider(widget.sessionId));
    }
  }

  Future<void> _refresh() async {
    _refreshLoaded();
    await ref.read(sessionDetailProvider(widget.sessionId).future);
  }

  void _showEventFeedback(SocketEvent event) {
    if (!mounted || event.data['sessionId'] != widget.sessionId) return;
    final session = ref.read(sessionDetailProvider(widget.sessionId)).value;
    final userId = ref.read(currentUserProvider)?.id;
    final player = session?.players
        .where((p) => p.userId == userId)
        .firstOrNull;
    final eventPlayerId =
        event.data['playerId'] ??
        (event.data['player'] is Map
            ? (event.data['player'] as Map)['id']
            : null);
    final playerIds = (event.data['playerIds'] as List<dynamic>? ?? const [])
        .whereType<String>();
    if (player == null ||
        (eventPlayerId != player.id && !playerIds.contains(player.id))) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final message = switch (event.name) {
      SessionEvent.playerRemoved => l10n.playerLiveRemoved,
      SessionEvent.playersDeselected => l10n.playerLiveDeselected,
      SessionEvent.playerUpdated => l10n.playerLiveUpdated,
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveSessionRealtimeProvider(widget.sessionId));
    final connected = ref.watch(socketConnectionProvider).value ?? false;
    final session = ref.watch(sessionDetailProvider(widget.sessionId));
    final userId = ref.watch(currentUserProvider)?.id;
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playerLiveTitle)),
      body: Column(
        children: [
          if (!connected) const _ReconnectingBanner(),
          Expanded(
            child: session.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                error: error,
                onRetry: () =>
                    ref.invalidate(sessionDetailProvider(widget.sessionId)),
              ),
              data: (value) {
                final player = value.players
                    .where(
                      (p) =>
                          p.userId == userId &&
                          p.registrationStatus == RegistrationStatus.approved,
                    )
                    .firstOrNull;
                if (player == null) {
                  return _AccessDenied(
                    onBack: () => context.go(AppRoutes.sessionDetail(value.id)),
                  );
                }
                return _Hub(
                  session: value,
                  player: player,
                  index: _index,
                  visited: _visited,
                  onRefresh: _refresh,
                  onSelect: (next) => setState(() {
                    _index = next;
                    _visited.add(next);
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Hub extends StatelessWidget {
  const _Hub({
    required this.session,
    required this.player,
    required this.index,
    required this.visited,
    required this.onSelect,
    required this.onRefresh,
  });
  final Session session;
  final SessionPlayer player;
  final int index;
  final Set<int> visited;
  final ValueChanged<int> onSelect;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = [
      (Icons.dashboard_outlined, l10n.playerLiveOverview),
      (Icons.person_pin_circle_outlined, l10n.playerLiveStatus),
      (Icons.sports_tennis_outlined, l10n.playerLiveCourts),
      (Icons.emoji_events_outlined, l10n.playerLiveResults),
      (Icons.payments_outlined, l10n.playerLivePayments),
    ];
    final pages = <Widget>[
      _Overview(session: session, player: player, onRefresh: onRefresh),
      _PlayerStatus(
        projection: PlayerLiveSession(session: session, player: player),
        onRefresh: onRefresh,
      ),
      _Courts(session: session, onRefresh: onRefresh),
      HostResultsTab(session: session, playerId: player.id, readOnly: true),
      PlayerLivePaymentTab(session: session),
    ];
    final content = IndexedStack(
      index: index,
      children: [
        for (var i = 0; i < pages.length; i++)
          visited.contains(i) ? pages[i] : const SizedBox.shrink(),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 700) {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                labelType: NavigationRailLabelType.all,
                destinations: [
                  for (final item in items)
                    NavigationRailDestination(
                      icon: Icon(item.$1),
                      label: Text(item.$2),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: content,
                  ),
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: content),
            SafeArea(
              top: false,
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: onSelect,
                destinations: [
                  for (final item in items)
                    NavigationDestination(icon: Icon(item.$1), label: item.$2),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.session,
    required this.player,
    required this.onRefresh,
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
    final roster = [
      ...session.approvedPlayers,
    ]..sort((a, b) => _statusOrder(a.status).compareTo(_statusOrder(b.status)));
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey('player-live-overview'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _SessionHeader(session: session),
          const SizedBox(height: AppSpacing.md),
          Text(
            session.description?.trim().isNotEmpty == true
                ? session.description!
                : l10n.playerLiveNoDescription,
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
              final own = all.where((s) => s.playerId == player.id).firstOrNull;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Stats(statistics: own),
                  if (own != null)
                    OutlinedButton.icon(
                      onPressed: () => showPlayerStatisticsExportSheet(
                        context,
                        session: session,
                        players: [own],
                        showShuttlecocks: false,
                      ),
                      icon: const Icon(Icons.share_outlined),
                      label: Text(l10n.hostPlayerStatsShare),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          playerMatches.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (matches) => _DoublesStats(
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
                if (value.hasRatedHost) {
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(l10n.playerLiveApprovedRating),
                    subtitle: Text(value.hostRating?.comment ?? ''),
                    trailing: Text('${value.hostRating?.rating ?? 0}/5'),
                  );
                }
                if (!value.canRateHost || session.hostAccountId == null) {
                  return const SizedBox.shrink();
                }
                return FilledButton.icon(
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
                );
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.playerLiveRoster,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final item in roster)
            Card(
              color: item.id == player.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${item.playerNumber ?? '–'}'),
                ),
                title: Text(
                  item.displayName ??
                      l10n.playerLiveNumber(item.playerNumber ?? 0),
                ),
                subtitle: Text(_statusLabel(l10n, item.status)),
              ),
            ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _PlayerStatus extends ConsumerWidget {
  const _PlayerStatus({required this.projection, required this.onRefresh});
  final PlayerLiveSession projection;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final player = projection.player;
    final start = projection.currentMatch?.startTime;
    final elapsed = start == null
        ? null
        : ref.watch(matchElapsedProvider(start)).value;
    String names(List<SessionPlayer> value) => value
        .map((p) => p.displayName ?? '#${p.playerNumber ?? '–'}')
        .join(', ');
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        key: const PageStorageKey('player-live-status'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${player.playerNumber ?? '–'}'),
              ),
              title: Text(
                player.displayName ??
                    l10n.playerLiveNumber(player.playerNumber ?? 0),
              ),
              subtitle: Text(_statusLabel(l10n, player.status)),
            ),
          ),
          _Info(
            Icons.sports_score,
            l10n.playerLiveMatches,
            '${player.matchesPlayed}',
          ),
          if (projection.waitingPosition != null)
            _Info(
              Icons.format_list_numbered,
              l10n.playerLiveQueuePosition,
              '#${projection.waitingPosition}',
            ),
          _Info(
            Icons.timer_outlined,
            start == null
                ? l10n.playerLiveWaitTime
                : l10n.playerLivePlayingTime,
            l10n.playerLiveMinutes(elapsed ?? player.currentWaitTime),
          ),
          if (projection.currentCourt == null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(child: Text(l10n.playerLiveNoCurrentCourt)),
            )
          else ...[
            _Info(
              Icons.place_outlined,
              l10n.playerLiveCurrentCourt,
              l10n.courtName(projection.currentCourt!),
            ),
            if (projection.partners.isNotEmpty)
              _Info(
                Icons.group_outlined,
                l10n.playerLivePartner,
                names(projection.partners),
              ),
            if (projection.opponents.isNotEmpty)
              _Info(
                Icons.groups_outlined,
                l10n.playerLiveOpponents,
                names(projection.opponents),
              ),
            const SizedBox(height: AppSpacing.md),
            BadmintonCourtView(
              court: projection.currentCourt!,
              highlightedPlayerId: player.id,
              preSelectedPlayers: projection.session.preSelectedPlayersFor(
                projection.currentCourt!,
              ),
              courtColor: parseHexColor(projection.session.courtColor),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

class _Courts extends StatelessWidget {
  const _Courts({required this.session, required this.onRefresh});
  final Session session;
  final Future<void> Function() onRefresh;
  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final courts = session.orderedCourts;
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final width =
            (constraints.maxWidth -
                AppSpacing.md * 2 -
                AppSpacing.md * (columns - 1)) /
            columns;
        return ListView(
          key: const PageStorageKey('player-live-courts'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (courts.isEmpty)
              SizedBox(
                height: 360,
                child: Center(
                  child: Text(AppLocalizations.of(context).liveNoCourts),
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final court in courts)
                    SizedBox(
                      width: width,
                      child: _CourtCard(session: session, court: court),
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        );
      },
    ),
  );
}

class _CourtCard extends ConsumerWidget {
  const _CourtCard({required this.session, required this.court});
  final Session session;
  final Court court;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final start = court.currentMatch?.startTime;
    final elapsed = start == null
        ? null
        : ref.watch(matchElapsedProvider(start)).value;
    final players = court.currentPlayers.isNotEmpty
        ? court.currentPlayers
        : session.preSelectedPlayersFor(court);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.courtName(court),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (elapsed != null) Text(l10n.playerLiveMinutes(elapsed)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            BadmintonCourtView(
              court: court,
              preSelectedPlayers: session.preSelectedPlayersFor(court),
              courtColor: parseHexColor(session.courtColor),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.livePlayerCount(players.length)),
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({required this.session});
  final Session session;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = switch (session.status) {
      SessionStatus.preparing => l10n.sessionStatusPreparing,
      SessionStatus.inProgress => l10n.sessionStatusInProgress,
      SessionStatus.finished => l10n.sessionStatusFinished,
      SessionStatus.cancelled => l10n.sessionStatusCancelled,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    session.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            if (session.timeRangeLabel != null) Text(session.timeRangeLabel!),
            if (session.priceLabel != null) Text(session.priceLabel!),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.statistics});
  final PlayerStatistics? statistics;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final s = statistics;
    final values = [
      (l10n.playerLiveMatches, '${s?.totalMatches ?? 0}'),
      (l10n.playerLiveWins, '${s?.wins ?? 0}'),
      (l10n.playerLiveLosses, '${s?.losses ?? 0}'),
      (l10n.playerLiveWinRate, '${(s?.winRate ?? 0).toStringAsFixed(0)}%'),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          SizedBox(
            width: 145,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Text(
                      value.$2,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(value.$1, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DoublesStats extends StatelessWidget {
  const _DoublesStats({
    required this.session,
    required this.player,
    required this.matches,
  });
  final Session session;
  final SessionPlayer player;
  final List<Match> matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    var men = 0;
    var women = 0;
    var mixed = 0;
    final roster = {for (final item in session.players) item.id: item};
    for (final match in matches.where((item) => item.players.length == 4)) {
      final ordered = [...match.players]
        ..sort((a, b) => a.position.compareTo(b.position));
      final index = ordered.indexWhere((item) => item.playerId == player.id);
      if (index < 0) continue;
      final partnerIndex = switch (index) {
        0 => 1,
        1 => 0,
        2 => 3,
        _ => 2,
      };
      final partner = roster[ordered[partnerIndex].playerId];
      if (player.gender == Gender.male && partner?.gender == Gender.male) {
        men++;
      } else if (player.gender == Gender.female &&
          partner?.gender == Gender.female) {
        women++;
      } else {
        mixed++;
      }
    }
    final values = [
      (l10n.playerLiveMensDoubles, men),
      (l10n.playerLiveWomensDoubles, women),
      (l10n.playerLiveMixedDoubles, mixed),
    ];
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final value in values)
          Chip(
            avatar: const Icon(Icons.groups_outlined, size: 18),
            label: Text('${value.$1}: ${value.$2}'),
          ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      trailing: Text(value, textAlign: TextAlign.end),
    ),
  );
}

class _ReconnectingBanner extends StatelessWidget {
  const _ReconnectingBanner();
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.errorContainer,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(AppLocalizations.of(context).liveReconnecting),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AccessDenied extends StatelessWidget {
  const _AccessDenied({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.playerLiveAccessDenied, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: onBack,
              child: Text(l10n.playerLiveBackToDetails),
            ),
          ],
        ),
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
String _statusLabel(AppLocalizations l10n, PlayerStatus status) =>
    switch (status) {
      PlayerStatus.playing => l10n.courtStatusInUse,
      PlayerStatus.ready => l10n.courtStatusReady,
      PlayerStatus.waiting => l10n.playerLiveWaitTime,
      PlayerStatus.finished => l10n.sessionStatusFinished,
      PlayerStatus.inactive => l10n.sessionStatusCancelled,
    };

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
