import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/city_selector.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/player/public_sessions_content.dart';
import 'package:vmito_app/features/session/presentation/player/session_filter_sheet.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/presentation/browse_clubs_screen.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';
import 'package:vmito_app/features/venue/presentation/browse_venues_screen.dart';
import 'package:vmito_app/features/venue/presentation/venue_filter_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';

/// The app's discovery landing page.
///
/// It mirrors the web discovery navigation: sessions are the default content,
/// while venues, clubs and tournaments are fetched when their segment is
/// selected. A keyed subtree deliberately recreates the active browser on
/// every selection (including a re-tap), so the selected data is revalidated.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    this.initialVenueId,
    this.initialVenueName,
    this.initialDiscoveryTab,
    super.key,
  });

  final String? initialVenueId;
  final String? initialVenueName;
  final HomeDiscoveryTab? initialDiscoveryTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late HomeDiscoveryTab _selectedTab;
  var _contentRevision = 0;
  bool _isFabExtended = true;
  final _searchQueries = <HomeDiscoveryTab, String>{};
  final _browseSnapshots = <HomeDiscoveryTab, Object>{};

  String? get _activeQuery => _searchQueries[_selectedTab];

  BrowseSessionFilters get _initialSessionFilters => BrowseSessionFilters(
    venueId: widget.initialVenueId,
    venueName: widget.initialVenueName,
  );

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialDiscoveryTab ?? HomeDiscoveryTab.sessions;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(CityOnboardingDialog.maybeShow(context, ref));
    });
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialVenueId == widget.initialVenueId &&
        oldWidget.initialVenueName == widget.initialVenueName &&
        oldWidget.initialDiscoveryTab == widget.initialDiscoveryTab) {
      return;
    }
    _selectedTab = widget.initialDiscoveryTab ?? HomeDiscoveryTab.sessions;
    _contentRevision++;
    _isFabExtended = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAuthenticated =
        ref.watch(authControllerProvider).status == AuthStatus.authenticated;
    final sessionState = ref.watch(browseSessionsControllerProvider);
    final venueState = ref.watch(venueBrowseControllerProvider);
    final clubsState = ref.watch(clubsControllerProvider);
    final tournamentState = ref.watch(tournamentBrowseControllerProvider);
    final preferredCity = ref
        .watch(locationPreferencesControllerProvider)
        .preferredCity;
    final activeQuery = _activeQuery;
    final discoveryHeader = HomeDiscoveryTabs(
      selected: _selectedTab,
      onSelected: _selectTab,
    );

    return Scaffold(
      appBar: activeQuery == null
          ? _buildBrowseAppBar(context, l10n, isAuthenticated)
          : _buildSearchResultsAppBar(
              context,
              l10n,
              activeQuery,
              sessionState.filters.activeCount,
              venueState.filter.activeCount(preferredCity: preferredCity),
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
        child: KeyedSubtree(
          key: ValueKey('${_selectedTab.name}-$_contentRevision'),
          child: switch (_selectedTab) {
            HomeDiscoveryTab.sessions => BrowseSessionsContent(
              discoveryHeader: discoveryHeader,
              initialFilters: activeQuery == null
                  ? _initialSessionFilters
                  : sessionState.filters,
            ),
            HomeDiscoveryTab.venues => BrowseVenuesScreen(
              embedded: true,
              discoveryHeader: discoveryHeader,
              initialFilter: activeQuery == null ? null : venueState.filter,
              showFilterSummary: activeQuery != null,
            ),
            HomeDiscoveryTab.clubs => BrowseClubsScreen(
              embedded: true,
              discoveryHeader: discoveryHeader,
              initialSearch: activeQuery ?? clubsState.search,
            ),
            HomeDiscoveryTab.tournaments => BrowseTournamentsContent(
              discoveryHeader: discoveryHeader,
              initialSearch: activeQuery ?? tournamentState.search,
            ),
          },
        ),
      ),
      floatingActionButton: switch (_selectedTab) {
        HomeDiscoveryTab.sessions => _buildCreateButton(
          context,
          l10n,
          key: 'home-create-session-fab',
          label: l10n.createSessionTitle,
          onPressed: isAuthenticated
              ? () => context.push(AppRoutes.createSession)
              : () => unawaited(
                  showLoginPromptDialog(
                    context,
                    featureName: l10n.loginRequiredCreateSession,
                    targetRoute: AppRoutes.createSession,
                  ),
                ),
        ),
        HomeDiscoveryTab.clubs => _buildCreateButton(
          context,
          l10n,
          key: 'home-create-club-fab',
          label: l10n.clubCreate,
          onPressed: isAuthenticated
              ? () => context.push(AppRoutes.createClub)
              : () => unawaited(
                  showLoginPromptDialog(
                    context,
                    featureName: l10n.loginRequiredCreateClub,
                    targetRoute: AppRoutes.createClub,
                  ),
                ),
        ),
        HomeDiscoveryTab.tournaments => _buildCreateButton(
          context,
          l10n,
          key: 'home-create-tournament-fab',
          label: l10n.tournamentCreate,
          onPressed: isAuthenticated
              ? () => context.push(AppRoutes.createTournament)
              : () => unawaited(
                  showLoginPromptDialog(
                    context,
                    featureName: l10n.loginRequiredCreateTournament,
                    targetRoute: AppRoutes.createTournament,
                  ),
                ),
        ),
        HomeDiscoveryTab.venues => null,
      },
    );
  }

  void _selectTab(HomeDiscoveryTab tab) => setState(() {
    _selectedTab = tab;
    _contentRevision++;
    _isFabExtended = true;
  });

  PreferredSizeWidget _buildBrowseAppBar(
    BuildContext context,
    AppLocalizations l10n,
    bool isAuthenticated,
  ) => AppBar(
    leading: IconButton(
      tooltip: l10n.menuOpenTooltip,
      icon: const Icon(AppIcons.menu),
      onPressed: () =>
          ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
    ),
    title: Text(_selectedTab.label(l10n)),
    actions: [
      IconButton(
        key: const Key('home-search-button'),
        tooltip: l10n.homeSearchTooltip,
        icon: const Icon(AppIcons.search),
        onPressed: _openSearch,
      ),
      if (isAuthenticated)
        const NotificationHeaderButton()
      else
        IconButton(
          tooltip: l10n.authSignIn,
          icon: const Icon(AppIcons.login),
          onPressed: () => context.push(AppRoutes.signIn),
        ),
    ],
  );

  PreferredSizeWidget _buildSearchResultsAppBar(
    BuildContext context,
    AppLocalizations l10n,
    String query,
    int sessionFilterCount,
    int venueFilterCount,
  ) => AppBar(
    leading: IconButton(
      key: const Key('home-search-exit-results'),
      tooltip: l10n.homeSearchExitResults,
      icon: const Icon(AppIcons.arrowBack),
      onPressed: _exitSearchResults,
    ),
    titleSpacing: 0,
    title: Semantics(
      button: true,
      label: l10n.homeSearchTooltip,
      child: InkWell(
        key: const Key('home-search-result-query'),
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
      if (_selectedTab == HomeDiscoveryTab.sessions)
        Badge(
          isLabelVisible: sessionFilterCount > 0,
          label: Text('$sessionFilterCount'),
          child: IconButton(
            key: const Key('home-search-session-filter'),
            tooltip: l10n.sessionFiltersTitle,
            icon: const Icon(AppIcons.tune),
            onPressed: _openSessionFilters,
          ),
        ),
      if (_selectedTab == HomeDiscoveryTab.venues)
        Badge(
          isLabelVisible: venueFilterCount > 0,
          label: Text('$venueFilterCount'),
          child: IconButton(
            key: const Key('home-search-venue-filter'),
            tooltip: l10n.venueFiltersTitle,
            icon: const Icon(AppIcons.tune),
            onPressed: _openVenueFilters,
          ),
        ),
      const SizedBox(width: 4),
    ],
  );

  Future<void> _openSearch() async {
    final tab = _selectedTab;
    final result = await context.push<String>(
      AppRoutes.homeSearchFor(tab.name, query: _searchQueries[tab]),
    );
    if (!mounted || result == null || result.isEmpty) return;
    _applySearch(tab, result);
  }

  void _applySearch(HomeDiscoveryTab tab, String query) {
    _browseSnapshots.putIfAbsent(tab, () => _snapshot(tab));
    setState(() => _searchQueries[tab] = query);
    switch (tab) {
      case HomeDiscoveryTab.sessions:
        final state = ref.read(browseSessionsControllerProvider);
        unawaited(
          ref
              .read(browseSessionsControllerProvider.notifier)
              .load(filters: state.filters.copyWith(search: query)),
        );
      case HomeDiscoveryTab.venues:
        final state = ref.read(venueBrowseControllerProvider);
        unawaited(
          ref
              .read(venueBrowseControllerProvider.notifier)
              .load(
                filter: state.filter.copyWith(
                  keyword: query,
                  sortBy: 'relevance',
                ),
              ),
        );
      case HomeDiscoveryTab.clubs:
        unawaited(
          ref.read(clubsControllerProvider.notifier).load(search: query),
        );
      case HomeDiscoveryTab.tournaments:
        unawaited(
          ref
              .read(tournamentBrowseControllerProvider.notifier)
              .load(
                search: query,
              ),
        );
    }
  }

  Object _snapshot(HomeDiscoveryTab tab) => switch (tab) {
    HomeDiscoveryTab.sessions => ref.read(browseSessionsControllerProvider),
    HomeDiscoveryTab.venues => ref.read(venueBrowseControllerProvider),
    HomeDiscoveryTab.clubs => ref.read(clubsControllerProvider),
    HomeDiscoveryTab.tournaments => ref.read(
      tournamentBrowseControllerProvider,
    ),
  };

  void _exitSearchResults() {
    final tab = _selectedTab;
    final snapshot = _browseSnapshots.remove(tab);
    switch ((tab, snapshot)) {
      case (HomeDiscoveryTab.sessions, final BrowseSessionsState state):
        ref.read(browseSessionsControllerProvider.notifier).restore(state);
      case (HomeDiscoveryTab.venues, final VenueBrowseState state):
        ref.read(venueBrowseControllerProvider.notifier).restore(state);
      case (HomeDiscoveryTab.clubs, final ClubsState state):
        ref.read(clubsControllerProvider.notifier).restore(state);
      case (HomeDiscoveryTab.tournaments, final TournamentBrowseState state):
        ref.read(tournamentBrowseControllerProvider.notifier).restore(state);
      default:
        break;
    }
    setState(() => _searchQueries.remove(tab));
  }

  Future<void> _openSessionFilters() async {
    final controller = ref.read(browseSessionsControllerProvider.notifier);
    final current = ref.read(browseSessionsControllerProvider).filters;
    final filters = await showModalBottomSheet<BrowseSessionFilters>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => SessionFilterSheet(initial: current),
    );
    if (filters != null) unawaited(controller.load(filters: filters));
  }

  Future<void> _openVenueFilters() async {
    final controller = ref.read(venueBrowseControllerProvider.notifier);
    final current = ref.read(venueBrowseControllerProvider).filter;
    final filter = await showModalBottomSheet<VenueFilter>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (context) => VenueFilterSheet(
        initial: current,
        preferredCity: ref
            .read(locationPreferencesControllerProvider)
            .preferredCity,
      ),
    );
    if (filter != null) unawaited(controller.load(filter: filter));
  }

  Widget _buildCreateButton(
    BuildContext context,
    AppLocalizations l10n, {
    required String key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: FloatingActionButton.extended(
        key: Key(key),
        heroTag: key,
        isExtended: _isFabExtended,
        onPressed: onPressed,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 2,
        extendedPadding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        icon: const Icon(AppIcons.add, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
