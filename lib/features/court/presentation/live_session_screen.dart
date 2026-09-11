import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/domain/player_live_session.dart';
import 'package:vmito_app/features/court/presentation/player_live_payment_tab.dart';
import 'package:vmito_app/features/court/presentation/widgets/live_session_overview_tab.dart';
import 'package:vmito_app/features/court/presentation/widgets/player_status_tab.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_status_badge.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
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
      appBar: AppBar(
        title: Text(
          session.maybeWhen(
            data: (value) => value.name,
            orElse: () => l10n.playerLiveTitle,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          session.maybeWhen(
            data: (value) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: SessionStatusBadge(status: value.status),
            ),
            orElse: SizedBox.shrink,
          ),
        ],
      ),
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
      (AppIcons.info, l10n.playerLiveOverview),
      (AppIcons.user, l10n.playerLiveStatus),
      (AppIcons.trophy, l10n.playerLiveResults),
      (AppIcons.dollarSign, l10n.playerLivePayments),
    ];
    final pages = <Widget>[
      LiveSessionOverviewTab(
        session: session,
        player: player,
        onRefresh: onRefresh,
      ),
      PlayerStatusTab(
        projection: PlayerLiveSession(session: session, player: player),
        onRefresh: onRefresh,
      ),
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
            AppBottomNavigationBar(
              key: const Key('player-live-bottom-nav'),
              selectedIndex: index,
              onDestinationSelected: onSelect,
              destinations: [
                for (var i = 0; i < items.length; i++)
                  NavigationDestination(
                    key: ValueKey('player-live-tab-$i'),
                    icon: Icon(items[i].$1),
                    label: items[i].$2,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
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

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
