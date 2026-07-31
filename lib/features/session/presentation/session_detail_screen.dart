import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/features/session/presentation/widgets/court_tile.dart';
import 'package:vmito_app/features/session/presentation/widgets/section_title.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_fee_section.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_header.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_player_summary.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Public session detail.
///
/// Reachable signed-out, like browse. Join actions come later; this screen is
/// currently read-only.
class SessionDetailScreen extends ConsumerWidget {
  const SessionDetailScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionDetailProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).sessionDetailTitle),
        actions: [
          if (session.asData?.value.status == SessionStatus.finished)
            IconButton(
              tooltip: AppLocalizations.of(context).socialRateSession,
              icon: const Icon(Icons.star_outline_rounded),
              onPressed: () => context.push(AppRoutes.rateSession(sessionId)),
            ),
          IconButton(
            tooltip: AppLocalizations.of(context).liveCourtOpen,
            icon: const Icon(Icons.stadium_outlined),
            onPressed: () => context.push(AppRoutes.liveSession(sessionId)),
          ),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(sessionDetailProvider(sessionId)),
        ),
        data: (session) => _Body(
          session: session,
          onRefresh: () => ref.refresh(sessionDetailProvider(sessionId).future),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.session, required this.onRefresh});

  final Session session;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: l10n.sessionTabOverview),
              Tab(text: l10n.sessionTabCourts),
              Tab(text: l10n.sessionTabPlayers),
              Tab(text: l10n.sessionTabFees),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RefreshList(
                  onRefresh: onRefresh,
                  children: [
                    if (session.coverPhoto case final url? when url.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: url,
                        height: 180,
                        fit: BoxFit.cover,
                        errorWidget: (context, _, _) => const SizedBox.shrink(),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SessionHeader(session: session),
                          if (session.description case final text?
                              when text.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            SectionTitle(l10n.sessionDescriptionTitle),
                            const SizedBox(height: AppSpacing.sm),
                            Text(text),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                _CourtsTab(session: session, onRefresh: onRefresh),
                _PlayersTab(session: session, onRefresh: onRefresh),
                _RefreshList(
                  onRefresh: onRefresh,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (session.feeConfig case final feeConfig?)
                      SessionFeeSection(feeConfig: feeConfig)
                    else
                      Center(child: Text(l10n.feeNotConfigured)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshList extends StatelessWidget {
  const _RefreshList({
    required this.onRefresh,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: onRefresh,
    child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        ...children,
        const SizedBox(height: AppSpacing.xxl),
      ],
    ),
  );
}

class _CourtsTab extends StatelessWidget {
  const _CourtsTab({required this.session, required this.onRefresh});

  final Session session;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final courts = session.orderedCourts;
    return _RefreshList(
      onRefresh: onRefresh,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (courts.isEmpty)
          Center(child: Text(AppLocalizations.of(context).liveNoCourts))
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 600 ? 3 : 2;
              final width =
                  (constraints.maxWidth - AppSpacing.sm * (columns - 1)) /
                  columns;
              return Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final court in courts)
                    SizedBox(
                      width: width,
                      child: CourtTile(court: court),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _PlayersTab extends StatelessWidget {
  const _PlayersTab({required this.session, required this.onRefresh});

  final Session session;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _RefreshList(
      onRefresh: onRefresh,
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        SessionPlayerSummary(session: session),
        const SizedBox(height: AppSpacing.md),
        for (final player in session.players)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${player.playerNumber ?? '•'}'),
              ),
              title: Text(l10n.playerName(player)),
              subtitle: player.level == null
                  ? null
                  : Text(l10n.levelName(player.level!)),
              trailing: Text(_playerStatus(l10n, player.status)),
            ),
          ),
      ],
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
