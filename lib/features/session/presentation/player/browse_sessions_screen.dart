import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/registration/presentation/my_join_requests_sheet.dart';
import 'package:vmito_app/features/registration/presentation/my_registration_sheet.dart';
import 'package:vmito_app/features/registration/presentation/register_session_sheet.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/pending_requests_screen.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';
import 'package:vmito_app/shared/widgets/app_skeleton.dart';
import 'package:vmito_app/shared/widgets/app_sort_selector.dart';

/// Authenticated hub for sessions the current user hosts or has joined.
class BrowseSessionsScreen extends ConsumerStatefulWidget {
  const BrowseSessionsScreen({super.key});

  @override
  ConsumerState<BrowseSessionsScreen> createState() =>
      _BrowseSessionsScreenState();
}

class _BrowseSessionsScreenState extends ConsumerState<BrowseSessionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  MySessionScope _scope = MySessionScope.hosted;
  final _scrollControllers = <MySessionScope, ScrollController>{};
  final _searchQueries = <MySessionScope, String>{};
  final _browseSnapshots = <MySessionScope, MySessionsState>{};
  bool _isFabExtended = true;
  late final VoidCallback _removeReselectHandler;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: MySessionScope.values.length,
      vsync: this,
      initialIndex: _scope.index,
    )..addListener(_onTabChanged);
    for (final scope in MySessionScope.values) {
      _scrollControllers[scope] = ScrollController()
        ..addListener(() => _onScroll(scope));
    }
    _removeReselectHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 1,
          onReselect: () => scrollToTop(_scrollControllers[_scope]!),
        );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadScope(_scope));
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _removeReselectHandler();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging ||
        _tabController.index == _scope.index ||
        !mounted) {
      return;
    }
    _setScope(MySessionScope.values[_tabController.index]);
  }

  void _onTabTap(int index) {
    _setScope(MySessionScope.values[index]);
  }

  void _setScope(MySessionScope scope) {
    if (scope == _scope) return;
    setState(() {
      _scope = scope;
      _isFabExtended = true;
    });
    if (_tabController.index != scope.index) {
      _tabController.animateTo(scope.index);
    }
    if (scope == MySessionScope.joined) {
      _loadScope(scope);
      unawaited(
        ref.read(myJoinRequestsControllerProvider.notifier).loadInitial(),
      );
    } else {
      _loadScope(scope);
    }
  }

  void _loadScope(MySessionScope scope) {
    unawaited(
      ref.read(mySessionsControllerProvider(scope).notifier).loadInitial(),
    );
  }

  void _onScroll(MySessionScope scope) {
    final position = _scrollControllers[scope]!.position;
    if (position.pixels >= position.maxScrollExtent - 500) {
      unawaited(
        ref.read(mySessionsControllerProvider(scope).notifier).loadMore(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..watch(mySessionsRealtimeProvider)
      ..watch(myJoinRequestsRealtimeProvider);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final state = ref.watch(mySessionsControllerProvider(_scope));
    final myJoinRequests = ref.watch(myJoinRequestsControllerProvider);
    final controller = ref.read(
      mySessionsControllerProvider(_scope).notifier,
    );
    ref.listen(mySessionsControllerProvider(_scope), (previous, next) {
      final hasContent = next.filter == MySessionFilter.pending
          ? next.pendingRequests.isNotEmpty
          : next.sessions.isNotEmpty;
      if (next.error != null && next.error != previous?.error && hasContent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorUnknown)));
      }
    });
    final activeQuery = _searchQueries[_scope];

    return Scaffold(
      appBar: activeQuery == null
          ? _buildBrowseAppBar(
              l10n: l10n,
              state: state,
              myJoinRequests: myJoinRequests,
              controller: controller,
              isAuthenticated: isAuthenticated,
            )
          : _buildSearchResultsAppBar(
              l10n: l10n,
              query: activeQuery,
            ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.axis == Axis.vertical) {
            if (notification.metrics.pixels <= 0) {
              if (!_isFabExtended) {
                setState(() => _isFabExtended = true);
              }
            } else if (notification is UserScrollNotification) {
              if (notification.direction == ScrollDirection.reverse) {
                if (_isFabExtended) {
                  setState(() => _isFabExtended = false);
                }
              } else if (notification.direction == ScrollDirection.forward) {
                if (!_isFabExtended) {
                  setState(() => _isFabExtended = true);
                }
              }
            }
          }
          return false;
        },
        child: Column(
          children: [
            _MySessionsToolbar(
              sortLabel: _sortLabel(l10n, state.sort),
              sortIcon: _sortIcon(state.sort),
              sortIsActive: state.sort != MySessionSort.dateNearest,
              filterIsActive: state.filter != MySessionFilter.active,
              onSort: () => _openSort(state, controller),
              onFilter: () => _openFilters(state, controller),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                child: _SessionsBody(
                  scope: _scope,
                  state: state,
                  scrollController: _scrollControllers[_scope]!,
                  onRetry: controller.refresh,
                  onDecision: (request, {required approved}) => unawaited(
                    controller.decideRequest(request, approved: approved),
                  ),
                  onDeleteSession: (session) => unawaited(
                    controller.deleteSession(session.id),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _scope == MySessionScope.hosted
          ? Tooltip(
              message: l10n.createSessionTitle,
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  key: const Key('my-sessions-create-fab'),
                  onPressed: () => context.push(AppRoutes.createSession),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    backgroundColor:
                        theme.extension<AppPalette>()?.brandSurface ??
                        (theme.brightness == Brightness.dark
                            ? const Color(0xFF183028)
                            : const Color(0xFFE2F3E8)),
                    foregroundColor: theme.colorScheme.primary,
                    elevation: 4,
                    shadowColor:
                        theme.colorScheme.shadow.withValues(alpha: 0.25),
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(
                        alpha: 0.35,
                      ),
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(AppIcons.add, size: 18),
                        if (_isFabExtended)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: Text(
                              l10n.createSessionTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.clip,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildTabBar(AppLocalizations l10n) => AppTabBar(
    key: const Key('my-sessions-scope'),
    controller: _tabController,
    onTap: _onTabTap,
    tabs: [
      Tab(
        key: const Key('my-sessions-scope-hosted'),
        text: l10n.mySessionsHosted,
      ),
      Tab(
        key: const Key('my-sessions-scope-joined'),
        text: l10n.mySessionsJoined,
      ),
    ],
  );

  PreferredSizeWidget _buildBrowseAppBar({
    required AppLocalizations l10n,
    required MySessionsState state,
    required MyJoinRequestsState myJoinRequests,
    required MySessionsController controller,
    required bool isAuthenticated,
  }) => AppBar(
    leading: IconButton(
      tooltip: l10n.menuOpenTooltip,
      icon: const Icon(AppIcons.menu),
      onPressed: () =>
          ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
    ),
    title: Text(l10n.mySessionsTitle),
    actions: [
      if (_scope == MySessionScope.hosted)
        IconButton(
          key: const Key('pending-requests-button'),
          tooltip: l10n.mySessionsPendingRequests,
          icon: Badge(
            isLabelVisible: state.pendingCount > 0,
            label: Text('${state.pendingCount}'),
            child: const Icon(AppIcons.clipboardList),
          ),
          onPressed: () => unawaited(showPendingRequestsSheet(context)),
        ),
      if (_scope == MySessionScope.joined)
        IconButton(
          key: const Key('my-join-requests-button'),
          tooltip: l10n.myJoinRequestsTitle,
          icon: Badge(
            isLabelVisible: myJoinRequests.total > 0,
            label: Text('${myJoinRequests.total}'),
            child: const Icon(AppIcons.clipboardList),
          ),
          onPressed: () => unawaited(
            showMyJoinRequestsSheet(
              context,
              onMutated: () => ref
                  .read(
                    mySessionsControllerProvider(
                      MySessionScope.joined,
                    ).notifier,
                  )
                  .refreshIfLoaded(),
            ),
          ),
        ),
      IconButton(
        key: const Key('my-sessions-search-button'),
        tooltip: l10n.homeSearchTooltip,
        icon: const Icon(AppIcons.search),
        onPressed: _openSearch,
      ),
      if (isAuthenticated)
        const NotificationHeaderButton(
          key: Key('my-sessions-notification-button'),
        )
      else
        IconButton(
          tooltip: l10n.authSignIn,
          icon: const Icon(AppIcons.login),
          onPressed: () => context.push(AppRoutes.signIn),
        ),
      const SizedBox(width: 8),
    ],
    bottom: _buildTabBar(l10n),
  );

  PreferredSizeWidget _buildSearchResultsAppBar({
    required AppLocalizations l10n,
    required String query,
  }) => AppBar(
    leading: IconButton(
      key: const Key('my-sessions-search-exit-results'),
      tooltip: l10n.homeSearchExitResults,
      icon: const Icon(AppIcons.arrowBack),
      onPressed: _exitSearchResults,
    ),
    titleSpacing: 0,
    title: Semantics(
      button: true,
      label: l10n.homeSearchTooltip,
      child: InkWell(
        key: const Key('my-sessions-search-result-query'),
        borderRadius: BorderRadius.circular(24),
        onTap: _openSearch,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.search, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  query,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: const [SizedBox(width: 4)],
    bottom: _buildTabBar(l10n),
  );

  void _openFilters(
    MySessionsState state,
    MySessionsController controller,
  ) => _showFilterBottomSheet(
    context: context,
    currentFilter: state.filter,
    onFilterSelected: (filter) => unawaited(controller.setFilter(filter)),
  );

  String _sortLabel(AppLocalizations l10n, MySessionSort sort) =>
      switch (sort) {
        MySessionSort.dateNearest => l10n.homeDiscoverySortDateNearest,
        MySessionSort.dateFurthest => l10n.homeDiscoverySortDateFurthest,
        MySessionSort.newest => l10n.homeDiscoverySortNewest,
      };

  IconData _sortIcon(MySessionSort sort) => switch (sort) {
    MySessionSort.dateNearest => AppIcons.calendarClock,
    MySessionSort.dateFurthest => AppIcons.calendarArrowDown,
    MySessionSort.newest => AppIcons.history,
  };

  void _openSort(MySessionsState state, MySessionsController controller) {
    unawaited(
      showAppSortSheet<MySessionSort>(
        context,
        title: AppLocalizations.of(context).homeDiscoverySortBy,
        selected: state.sort,
        keyPrefix: 'my-sessions-sort',
        options: [
          for (final sort in MySessionSort.values)
            AppSortOption(
              value: sort,
              keyValue: sort.name,
              label: _sortLabel(AppLocalizations.of(context), sort),
              icon: _sortIcon(sort),
            ),
        ],
      ).then((sort) {
        if (sort != null) unawaited(controller.setSort(sort));
      }),
    );
  }

  Future<void> _openSearch() async {
    final scope = _scope;
    final result = await context.push<String>(
      AppRoutes.mySessionsSearchFor(
        scope.name,
        query: _searchQueries[scope],
      ),
    );
    if (!mounted || result == null || result.isEmpty) return;
    _browseSnapshots.putIfAbsent(
      scope,
      () => ref.read(mySessionsControllerProvider(scope)),
    );
    setState(() => _searchQueries[scope] = result);
    unawaited(
      ref.read(mySessionsControllerProvider(scope).notifier).setSearch(result),
    );
  }

  void _exitSearchResults() {
    final scope = _scope;
    final snapshot = _browseSnapshots.remove(scope);
    if (snapshot != null) {
      ref.read(mySessionsControllerProvider(scope).notifier).restore(snapshot);
    }
    setState(() => _searchQueries.remove(scope));
  }

  void _showFilterBottomSheet({
    required BuildContext context,
    required MySessionFilter currentFilter,
    required ValueChanged<MySessionFilter> onFilterSelected,
  }) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (context) => _FilterBottomSheet(
          currentFilter: currentFilter,
          onFilterSelected: onFilterSelected,
        ),
      ),
    );
  }
}

class _MySessionsToolbar extends StatelessWidget {
  const _MySessionsToolbar({
    required this.sortLabel,
    required this.sortIcon,
    required this.sortIsActive,
    required this.filterIsActive,
    required this.onSort,
    required this.onFilter,
  });

  final String sortLabel;
  final IconData sortIcon;
  final bool sortIsActive;
  final bool filterIsActive;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final filterForeground = filterIsActive
        ? Theme.of(context).colorScheme.primary
        : palette.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: AppSortSelector(
              buttonKey: const Key('my-sessions-sort-button'),
              label: sortLabel,
              icon: sortIcon,
              isActive: sortIsActive,
              onPressed: onSort,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            key: const Key('my-sessions-filter-button'),
            tooltip: l10n.sessionFiltersTitle,
            onPressed: onFilter,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(foregroundColor: filterForeground),
            icon: const Icon(AppIcons.tune, size: 20),
          ),
        ],
      ),
    );
  }
}

class _FilterBottomSheet extends StatelessWidget {
  const _FilterBottomSheet({
    required this.currentFilter,
    required this.onFilterSelected,
  });

  final MySessionFilter currentFilter;
  final ValueChanged<MySessionFilter> onFilterSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final filters = [
      (MySessionFilter.active, l10n.mySessionsActive),
      (MySessionFilter.ended, l10n.mySessionsEnded),
      (MySessionFilter.all, l10n.mySessionsAll),
    ];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppSheetHeader(title: l10n.sessionFiltersTitle),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...filters.map((item) {
                  final filter = item.$1;
                  final label = item.$2;
                  final isSelected = filter == currentFilter;
                  return ListTile(
                    key: ValueKey('my-sessions-filter-${filter.name}'),
                    title: Text(
                      label,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            AppIcons.check,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                    onTap: () {
                      onFilterSelected(filter);
                      Navigator.of(context).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsBody extends StatelessWidget {
  const _SessionsBody({
    required this.scope,
    required this.state,
    required this.scrollController,
    required this.onRetry,
    required this.onDecision,
    this.onDeleteSession,
  });

  final MySessionScope scope;
  final MySessionsState state;
  final ScrollController scrollController;
  final Future<void> Function() onRetry;
  final void Function(PendingJoinRequest, {required bool approved}) onDecision;
  final ValueChanged<Session>? onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPending = state.filter == MySessionFilter.pending;
    if (state.isLoading && !state.hasLoaded && !isPending) {
      return _MySessionsSkeleton(scope: scope);
    }
    final isEmpty = isPending
        ? state.pendingRequests.isEmpty
        : state.sessions.isEmpty;
    if (state.error != null && isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onRetry);
    }
    if (isEmpty) return _EmptyMySessionsView(scope: scope);
    if (isPending) {
      return ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.pendingRequests.length + (state.isLoadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index == state.pendingRequests.length) {
            return const AppLoadingView();
          }
          final request = state.pendingRequests[index];
          return _PendingRequestCard(
            request: request,
            busy: state.actingRequestId == request.id,
            onDecision: (approved) => onDecision(request, approved: approved),
          );
        },
      );
    }
    return ListView.separated(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: state.sessions.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        if (index == state.sessions.length) return const AppLoadingView();
        final session = state.sessions[index];
        final registrationStatus = scope == MySessionScope.joined
            ? _registrationStatus(session)
            : null;
        final card = SessionCard(
          key: ValueKey(session.id),
          session: session,
          hideHostInfo: scope == MySessionScope.hosted,
          onTap: () => context.push(AppRoutes.sessionDetail(session.id)),
          onHost: scope == MySessionScope.hosted
              ? () => context.push(AppRoutes.manageSession(session.id))
              : null,
          onClone: scope == MySessionScope.hosted
              ? () => context.push(AppRoutes.cloneSession(session.id))
              : null,
          onDownloadImage: scope == MySessionScope.hosted
              ? () => _downloadImage(context, session)
              : null,
          onShare: scope == MySessionScope.hosted
              ? () => _shareSession(context, session)
              : null,
          onDelete: scope == MySessionScope.hosted
              ? () => _confirmDelete(context, session)
              : null,
          compactStatusBadge: scope == MySessionScope.hosted,
          showSessionStatusBadge:
              scope == MySessionScope.hosted || scope == MySessionScope.joined,
          sessionStatusBadgeAtTop: scope == MySessionScope.hosted,
          extraTimeTopSpacing: scope == MySessionScope.hosted,
          registrationStatus: registrationStatus,
          primaryAction: scope == MySessionScope.joined
              ? SessionCardAction(
                  label: l10n.sessionViewBoard,
                  icon: AppIcons.court,
                  onPressed: registrationStatus == RegistrationStatus.pending
                      ? null
                      : () => context.push(AppRoutes.liveSession(session.id)),
                )
              : null,
          moreActions: scope == MySessionScope.joined
              ? [
                  SessionCardAction(
                    label: l10n.sessionViewMyRegistration,
                    icon: AppIcons.ticket,
                    onPressed: () => _showTicket(context, session.id),
                  ),
                  SessionCardAction(
                    label: l10n.sessionAddGuest,
                    icon: AppIcons.userPlus,
                    onPressed: () => unawaited(
                      showRegisterSessionSheet(
                        context,
                        session: session,
                        asGuest: true,
                      ),
                    ),
                  ),
                  SessionCardAction(
                    label: l10n.mySessionsShare,
                    icon: AppIcons.share,
                    onPressed: () => _shareSession(context, session),
                  ),
                ]
              : const [],
        );
        return card;
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.mySessionsDeleteConfirmTitle,
      content: l10n.mySessionsDeleteConfirmMessage,
      confirmLabel: l10n.mySessionsDelete,
    );

    if (confirmed == true && context.mounted) {
      onDeleteSession?.call(session);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.mySessionsDeleteSuccess)),
      );
    }
  }

  void _shareSession(BuildContext context, Session session) {
    final url = 'https://vmito.com/sessions/${session.id}';
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: '${session.name}\n$url', subject: session.name),
      ),
    );
  }

  void _showTicket(BuildContext context, String sessionId) {
    unawaited(showMyRegistrationSheet(context, sessionId: sessionId));
  }

  void _downloadImage(BuildContext context, Session session) {
    final l10n = AppLocalizations.of(context);
    final imageUrl = sessionCoverPhoto(session);
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: imageUrl, subject: session.name),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mySessionsDownloadSuccess)),
    );
  }

  RegistrationStatus? _registrationStatus(Session session) =>
      session.players.isEmpty ? null : session.players.first.registrationStatus;
}

class _MySessionsSkeleton extends StatelessWidget {
  const _MySessionsSkeleton({required this.scope});

  final MySessionScope scope;

  @override
  Widget build(BuildContext context) => AppSkeletonList(
    listKey: const Key('my-sessions-skeleton-list'),
    itemExtentEstimate: 220,
    itemBuilder: (context) => SessionCardSkeleton(
      showHostInfo: scope != MySessionScope.hosted,
      showActions: true,
    ),
  );
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.busy,
    required this.onDecision,
  });

  final PendingJoinRequest request;
  final bool busy;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final date = request.startTime == null
        ? null
        : DateFormat.yMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_Hm().format(request.startTime!.toLocal());
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.playerName?.trim().isNotEmpty ?? false
                  ? request.playerName!
                  : l10n.mySessionsUnknownPlayer,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(request.sessionName),
            if (request.venueName != null) Text(request.venueName!),
            if (date != null) Text(date),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: ValueKey('reject-request-${request.id}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: busy ? null : () => onDecision(false),
                    child: Text(l10n.hostManageReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('approve-request-${request.id}'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: busy ? null : () => onDecision(true),
                    child: busy
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.hostManageApprove),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyMySessionsView extends StatelessWidget {
  const _EmptyMySessionsView({required this.scope});

  final MySessionScope scope;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPalette>()!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
        Icon(
          AppIcons.calendarX,
          size: 48,
          color: palette.mutedForeground,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          switch (scope) {
            MySessionScope.hosted => AppLocalizations.of(
              context,
            ).mySessionsHostedEmpty,
            MySessionScope.joined => AppLocalizations.of(
              context,
            ).mySessionsJoinedEmpty,
          },
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
