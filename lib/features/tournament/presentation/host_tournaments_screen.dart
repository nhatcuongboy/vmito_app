import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/application/host_tournaments_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/host_tournament_actions.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournament_card.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournament_card_skeleton.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournament_more_menu.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournaments_create_fab.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournaments_empty_view.dart';
import 'package:vmito_app/features/tournament/presentation/widgets/host_tournaments_search_bar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/app_sort_selector.dart';

/// "My tournaments" — ports `vmito-fe` `host/tournaments/page.tsx`.
///
/// Tournament detail and management stay on web for now and open in the
/// in-app browser; the list refreshes on return in case they changed there.
class HostTournamentsScreen extends ConsumerStatefulWidget {
  const HostTournamentsScreen({super.key});

  @override
  ConsumerState<HostTournamentsScreen> createState() =>
      _HostTournamentsScreenState();
}

class _HostTournamentsScreenState extends ConsumerState<HostTournamentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Mirrors the "Bản đồ" toggle on the sessions/venues discovery lists: the
  // create action shrinks to icon-only while scrolling down and expands back
  // at the top or on scroll-up, so it never idles as a wide label over cards.
  bool _isFabExtended = true;

  HostTournamentsController get _controller =>
      ref.read(hostTournamentsControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: HostTournamentTab.values.length,
      vsync: this,
      initialIndex: ref.read(hostTournamentsControllerProvider).tab.index,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.loadInitial());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(hostTournamentsControllerProvider);
    final user = ref.watch(currentUserProvider);
    // Any authenticated user can create a tournament, regardless of role.
    final canCreate = user != null;
    ref.listen(hostTournamentsControllerProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          next.hasLoaded) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
      }
    });
    final tabBar = AppTabBar(
      controller: _tabController,
      onTap: (index) {
        _controller.setTab(HostTournamentTab.values[index]);
        if (!_isFabExtended) setState(() => _isFabExtended = true);
      },
      tabs: [
        Tab(text: l10n.hostTournamentsTabOpen),
        Tab(text: l10n.hostTournamentsTabEnded),
        Tab(text: l10n.hostTournamentsTabAll),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          user?.isAdmin ?? false
              ? l10n.hostTournamentsAdminTitle
              : l10n.hostTournamentsTitle,
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60 + tabBar.preferredSize.height),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  4,
                  AppSpacing.md,
                  12,
                ),
                child: HostTournamentsSearchBar(
                  onChanged: _controller.setSearch,
                  onSortPressed: () => unawaited(_pickSort(state.sort)),
                  isSortActive: state.sort != TournamentBrowseSort.startAsc,
                ),
              ),
              tabBar,
            ],
          ),
        ),
      ),
      floatingActionButton: canCreate && state.hasLoaded
          ? HostTournamentsCreateFab(
              isExtended: _isFabExtended,
              label: l10n.tournamentCreate,
              onPressed: () => unawaited(_create()),
            )
          : null,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: _buildBody(state, user, canCreate: canCreate),
      ),
    );
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification.metrics.pixels <= 0) {
      if (!_isFabExtended) setState(() => _isFabExtended = true);
    } else if (notification is UserScrollNotification) {
      if (notification.direction == ScrollDirection.reverse) {
        if (_isFabExtended) setState(() => _isFabExtended = false);
      } else if (notification.direction == ScrollDirection.forward) {
        if (!_isFabExtended) setState(() => _isFabExtended = true);
      }
    }
    return false;
  }

  Widget _buildBody(
    HostTournamentsState state,
    User? user, {
    required bool canCreate,
  }) {
    if (!state.hasLoaded) {
      if (state.error case final error? when !state.isLoading) {
        return AppErrorView(
          error: error,
          onRetry: () => unawaited(_controller.refresh()),
        );
      }
      return AppSkeletonList(
        listKey: const Key('host-tournaments-skeleton'),
        itemBuilder: (_) => const HostTournamentCardSkeleton(),
        itemExtentEstimate: 104,
        gap: 12,
      );
    }
    final items = state.visible;
    return RefreshIndicator(
      onRefresh: _controller.refresh,
      child: items.isEmpty
          ? HostTournamentsEmptyView(
              kind: state.tournaments.isNotEmpty || state.query.isNotEmpty
                  ? HostTournamentsEmptyKind.noResults
                  : user?.isAdmin ?? false
                  ? HostTournamentsEmptyKind.admin
                  : HostTournamentsEmptyKind.host,
              onCreate: canCreate ? () => unawaited(_create()) : null,
            )
          : ListView.separated(
              key: const Key('host-tournaments-list'),
              physics: const AlwaysScrollableScrollPhysics(),
              // Bottom room so the FAB never covers the last card's menu.
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                96,
              ),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildCard(
                items[index],
                user,
                deletingId: state.deletingId,
              ),
            ),
    );
  }

  Widget _buildCard(
    TournamentSummary tournament,
    User? user, {
    required String? deletingId,
  }) {
    final l10n = AppLocalizations.of(context);
    final isReferee = user?.role == UserRole.referee;
    // The backend lets only the host or an ADMIN delete; managers and umpires
    // would get a 403, so the action is not offered to them.
    final canDelete =
        !isReferee &&
        user != null &&
        (user.isAdmin || tournament.hostId == user.id);
    return HostTournamentCard(
      key: ValueKey('host-tournament-${tournament.id}'),
      tournament: tournament,
      isDeleting: deletingId == tournament.id,
      onTap: () => unawaited(_open(tournament, asReferee: isReferee)),
      actions: [
        HostTournamentCardAction(
          label: isReferee
              ? l10n.hostTournamentsReferee
              : l10n.tournamentManageOpen,
          icon: isReferee ? AppIcons.gavel : AppIcons.settings,
          onPressed: () => unawaited(_open(tournament, asReferee: isReferee)),
        ),
        HostTournamentCardAction(
          label: l10n.commonShare,
          icon: AppIcons.share,
          onPressed: () => unawaited(shareHostTournament(context, tournament)),
        ),
        if (canDelete)
          HostTournamentCardAction(
            label: l10n.commonDelete,
            icon: AppIcons.delete,
            isDestructive: true,
            onPressed: () => unawaited(_confirmDelete(tournament)),
          ),
      ],
    );
  }

  Future<void> _open(
    TournamentSummary tournament, {
    bool asReferee = false,
  }) async {
    await openHostTournamentWeb(context, tournament, asReferee: asReferee);
    if (mounted) await _controller.refresh();
  }

  Future<void> _create() async {
    final created = await context.push<TournamentSummary>(
      AppRoutes.createTournament,
    );
    if (!mounted) return;
    unawaited(_controller.refresh());
    if (created != null) await _open(created);
  }

  Future<void> _pickSort(TournamentBrowseSort selected) async {
    final l10n = AppLocalizations.of(context);
    final sort = await showAppSortSheet<TournamentBrowseSort>(
      context,
      title: l10n.homeDiscoverySortBy,
      selected: selected,
      keyPrefix: 'host-tournaments-sort',
      options: [
        for (final option in TournamentBrowseSort.values)
          AppSortOption(
            value: option,
            keyValue: option.name,
            label: switch (option) {
              TournamentBrowseSort.startAsc =>
                l10n.homeDiscoverySortStartSoonest,
              TournamentBrowseSort.newest => l10n.homeDiscoverySortNewest,
              TournamentBrowseSort.nameAsc => l10n.homeDiscoverySortNameAsc,
              TournamentBrowseSort.nameDesc => l10n.homeDiscoverySortNameDesc,
            },
            icon: switch (option) {
              TournamentBrowseSort.startAsc => AppIcons.calendarClock,
              TournamentBrowseSort.newest => AppIcons.calendarArrowDown,
              TournamentBrowseSort.nameAsc => AppIcons.sortAlpha,
              TournamentBrowseSort.nameDesc => AppIcons.sortAlphaDesc,
            },
          ),
      ],
    );
    if (sort != null) _controller.setSort(sort);
  }

  Future<void> _confirmDelete(TournamentSummary tournament) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.tournamentManageDelete,
      content: l10n.hostTournamentsDeleteConfirm,
      confirmLabel: l10n.commonDelete,
      type: AppConfirmDialogType.destructive,
      confirmKey: const Key('host-tournament-delete-confirm'),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.delete(tournament.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hostTournamentsDeleted)),
      );
    } on ApiException {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.hostTournamentsDeleteFailed)),
      );
    }
  }
}
