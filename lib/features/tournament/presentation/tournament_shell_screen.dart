import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_detail_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_schedule_screen.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_standings_screen.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_dashboard_tab.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/tournament_teams_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// The public tournament page: `/tournaments/:id`.
///
/// Hosts the native ports of the web shell's tabs. Each tab owns its own
/// controller and scroll view, so the shell only supplies the chrome.
class TournamentShellScreen extends ConsumerStatefulWidget {
  const TournamentShellScreen({
    required this.idOrSlug,
    this.initialTab = 0,
    super.key,
  });

  final String idOrSlug;
  final int initialTab;

  @override
  ConsumerState<TournamentShellScreen> createState() =>
      _TournamentShellScreenState();
}

class _TournamentShellScreenState extends ConsumerState<TournamentShellScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(
      tournamentDetailControllerProvider(widget.idOrSlug),
    );
    final access = ref
        .watch(tournamentManageAccessProvider(widget.idOrSlug))
        .value;
    final canManage = access?.canManage ?? false;
    // Web gate: host or ADMIN only — assigned managers do not get a dashboard.
    final showDashboard = access?.isHostOrAdmin ?? false;
    final tabCount = showDashboard ? 5 : 4;

    // DefaultTabController (not a local TabController) so descendants of the
    // Home tab can switch tabs — the quick actions do.
    return DefaultTabController(
      length: tabCount,
      // An out-of-range tab (e.g. a dashboard link for a non-host) opens Home,
      // matching the web's redirect to the tournament root.
      initialIndex: widget.initialTab < tabCount ? widget.initialTab : 0,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            detail.value?.tournament.name ?? l10n.tournamentDetailTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (canManage)
              IconButton(
                tooltip: l10n.tournamentManageOpen,
                onPressed: () => unawaited(
                  context.push(AppRoutes.manageTournament(widget.idOrSlug)),
                ),
                icon: const Icon(AppIcons.settings),
              ),
          ],
          bottom: AppTabBar(
            tabs: [
              Tab(text: l10n.tournamentTabHome),
              Tab(text: l10n.tournamentTabTeams),
              Tab(text: l10n.tournamentTabSchedule),
              Tab(text: l10n.tournamentTabStandings),
              if (showDashboard) Tab(text: l10n.tournamentTabDashboard),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeTab(idOrSlug: widget.idOrSlug),
            TournamentTeamsTab(idOrSlug: widget.idOrSlug),
            TournamentScheduleScreen(idOrSlug: widget.idOrSlug, embedded: true),
            TournamentStandingsScreen(
              idOrSlug: widget.idOrSlug,
              embedded: true,
            ),
            if (showDashboard)
              TournamentDashboardTab(idOrSlug: widget.idOrSlug),
          ],
        ),
      ),
    );
  }
}

/// Tab indices the quick actions on the Home tab jump to.
abstract final class TournamentShellTab {
  static const home = 0;
  static const teams = 1;
  static const schedule = 2;
  static const standings = 3;
  static const dashboard = 4;
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab({required this.idOrSlug});

  final String idOrSlug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(tournamentDetailControllerProvider(idOrSlug));
    final controller = ref.read(
      tournamentDetailControllerProvider(idOrSlug).notifier,
    );
    return detail.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorView(
        error: error,
        onRetry: () => unawaited(controller.refresh()),
      ),
      data: (state) => TournamentHomeContent(
        state: state,
        onRefresh: controller.refresh,
        onRetryMatches: () =>
            controller.refreshLiveSections(refreshStandings: false),
      ),
    );
  }
}
