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
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/registration/presentation/my_join_requests_sheet.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/pending_requests_screen.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// Authenticated hub for sessions the current user hosts or has joined.
class BrowseSessionsScreen extends ConsumerStatefulWidget {
  const BrowseSessionsScreen({super.key});

  @override
  ConsumerState<BrowseSessionsScreen> createState() =>
      _BrowseSessionsScreenState();
}

class _BrowseSessionsScreenState extends ConsumerState<BrowseSessionsScreen> {
  MySessionScope _scope = MySessionScope.hosted;
  final _scrollControllers = <MySessionScope, ScrollController>{};
  final _searchQueries = <MySessionScope, String>{};
  final _browseSnapshots = <MySessionScope, MySessionsState>{};
  bool _isFabExtended = true;
  late final VoidCallback _removeReselectHandler;

  @override
  void initState() {
    super.initState();
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
    _removeReselectHandler();
    for (final controller in _scrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
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
              state: state,
              controller: controller,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<MySessionScope>(
                  key: const Key('my-sessions-scope'),
                  segments: [
                    ButtonSegment(
                      value: MySessionScope.hosted,
                      label: Text(l10n.mySessionsHosted),
                    ),
                    ButtonSegment(
                      value: MySessionScope.joined,
                      label: Text(l10n.mySessionsJoined),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: (selection) {
                    final scope = selection.single;
                    if (scope == _scope) return;
                    setState(() {
                      _scope = scope;
                      _isFabExtended = true;
                    });
                    if (scope == MySessionScope.joined) {
                      _loadScope(scope);
                      unawaited(
                        ref
                            .read(myJoinRequestsControllerProvider.notifier)
                            .loadInitial(),
                      );
                    } else {
                      _loadScope(scope);
                    }
                  },
                ),
              ),
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
      floatingActionButton: SizedBox(
        height: 40,
        child: FloatingActionButton.extended(
          key: const Key('my-sessions-create-fab'),
          heroTag: 'my-sessions-create-session-fab',
          isExtended: _isFabExtended,
          onPressed: () => context.push(AppRoutes.createSession),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 2,
          extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          icon: const Icon(AppIcons.add, size: 18),
          label: Text(l10n.createSessionTitle),
        ),
      ),
    );
  }

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
            child: const Icon(AppIcons.userCheck),
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
        key: const Key('my-sessions-filter-button'),
        tooltip: l10n.sessionFiltersTitle,
        icon: const Icon(AppIcons.tune),
        onPressed: () => _openFilters(state, controller),
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
  );

  PreferredSizeWidget _buildSearchResultsAppBar({
    required AppLocalizations l10n,
    required String query,
    required MySessionsState state,
    required MySessionsController controller,
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
    actions: [
      IconButton(
        key: const Key('my-sessions-filter-button'),
        tooltip: l10n.sessionFiltersTitle,
        icon: const Icon(AppIcons.tune),
        onPressed: () => _openFilters(state, controller),
      ),
      const SizedBox(width: 4),
    ],
  );

  void _openFilters(
    MySessionsState state,
    MySessionsController controller,
  ) => _showFilterBottomSheet(
    context: context,
    currentFilter: state.filter,
    onFilterSelected: (filter) => unawaited(controller.setFilter(filter)),
  );

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
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.sessionFiltersTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(AppIcons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
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
    if (state.isLoading && !state.hasLoaded) return const AppLoadingView();
    final isPending = state.filter == MySessionFilter.pending;
    final isEmpty = isPending
        ? state.pendingRequests.isEmpty
        : state.sessions.isEmpty;
    if (state.error != null && isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onRetry);
    }
    if (isEmpty) return const _EmptyMySessionsView();
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
        final card = SessionCard(
          session: session,
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
        );
        if (scope == MySessionScope.joined && _isPending(session)) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              card,
              Positioned(
                top: AppSpacing.xs,
                right: AppSpacing.xs,
                child: Chip(
                  key: const Key('joined-session-pending-badge'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    AppLocalizations.of(context).mySessionsPendingBadge,
                  ),
                ),
              ),
            ],
          );
        }
        return card;
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.mySessionsDeleteConfirmTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 320),
          child: Text(l10n.mySessionsDeleteConfirmMessage),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.mySessionsDelete),
          ),
        ],
      ),
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

  void _downloadImage(BuildContext context, Session session) {
    final l10n = AppLocalizations.of(context);
    final imageUrl = session.coverPhoto?.trim().isNotEmpty ?? false
        ? session.coverPhoto!.trim()
        : Session.defaultCoverPhoto;
    unawaited(
      SharePlus.instance.share(
        ShareParams(text: imageUrl, subject: session.name),
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.mySessionsDownloadSuccess)),
    );
  }

  bool _isPending(Session session) =>
      session.players.any((player) => player.isPendingApproval);
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
                    onPressed: busy ? null : () => onDecision(false),
                    child: Text(l10n.hostManageReject),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: ValueKey('approve-request-${request.id}'),
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
  const _EmptyMySessionsView();

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
          AppLocalizations.of(context).mySessionsEmpty,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
