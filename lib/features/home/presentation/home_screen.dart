import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell_scaffold_key.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/widgets/city_onboarding_dialog.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_filter_sheets.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_tabs.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_discovery_toolbar.dart';
import 'package:vmito_app/features/home/presentation/widgets/home_header_backdrop.dart';
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
import 'package:vmito_app/shared/widgets/app_sort_selector.dart';

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
      if (mounted) unawaited(_showCityOnboarding());
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final currentUser = authState.user;
    final canCreateTournament =
        currentUser?.role == UserRole.host ||
        currentUser?.role == UserRole.admin;
    final sessionState = ref.watch(browseSessionsControllerProvider);
    final venueState = ref.watch(venueBrowseControllerProvider);
    final clubsState = ref.watch(clubsControllerProvider);
    final tournamentState = ref.watch(tournamentBrowseControllerProvider);
    final preferredCity = ref
        .watch(locationPreferencesControllerProvider)
        .preferredCity;
    final activeQuery = _activeQuery;
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final discoveryHeader = DecoratedBox(
      key: const Key('home-discovery-header'),
      decoration: BoxDecoration(
        gradient: HomeHeaderTint.of(context).headerGradient,
        border: Border(bottom: BorderSide(color: palette.border)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(
              alpha: theme.brightness == Brightness.light ? 0.06 : 0.20,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HomeDiscoveryTabs(
            selected: _selectedTab,
            onSelected: _selectTab,
          ),
          HomeDiscoveryToolbar(
            sortLabel: _sortLabel(
              l10n,
              sessionState,
              venueState,
              clubsState,
              tournamentState,
            ),
            sortIcon: _sortIcon(
              sessionState,
              venueState,
              clubsState,
              tournamentState,
            ),
            filterCount: _filterCount(
              sessionState,
              venueState,
              clubsState,
              tournamentState,
              preferredCity,
            ),
            sortIsActive: _hasCustomSort(
              sessionState,
              venueState,
              clubsState,
              tournamentState,
            ),
            onSort: _openActiveSort,
            onFilter: _openActiveFilters,
            onCityChanged: _onPreferredCityChanged,
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: activeQuery == null
          ? _buildBrowseAppBar(
              context,
              l10n,
              isAuthenticated,
              canCreateTournament,
            )
          : _buildSearchResultsAppBar(
              context,
              l10n,
              activeQuery,
            ),
      body: KeyedSubtree(
        key: ValueKey('${_selectedTab.name}-$_contentRevision'),
        child: switch (_selectedTab) {
          HomeDiscoveryTab.sessions => BrowseSessionsContent(
            discoveryHeader: discoveryHeader,
            showMapToggle: isAuthenticated,
            initialFilters: activeQuery == null
                ? _initialSessionFilters
                : sessionState.filters,
          ),
          HomeDiscoveryTab.venues => BrowseVenuesScreen(
            embedded: true,
            discoveryHeader: discoveryHeader,
            initialFilter: activeQuery == null ? null : venueState.filter,
            showFilterSummary: activeQuery != null,
            showMapToggle: isAuthenticated,
          ),
          HomeDiscoveryTab.clubs => BrowseClubsScreen(
            embedded: true,
            discoveryHeader: discoveryHeader,
            initialSearch: activeQuery ?? clubsState.search,
            showMapToggle: isAuthenticated,
          ),
          HomeDiscoveryTab.tournaments => BrowseTournamentsContent(
            discoveryHeader: discoveryHeader,
            initialSearch: activeQuery ?? tournamentState.search,
            showMapToggle: isAuthenticated,
          ),
        },
      ),
    );
  }

  void _selectTab(HomeDiscoveryTab tab) => setState(() {
    _selectedTab = tab;
    _contentRevision++;
  });

  Future<void> _showCityOnboarding() async {
    final result = await CityOnboardingDialog.maybeShow(context, ref);
    if (result != null && mounted) {
      await _onPreferredCityChanged(result.city);
    }
  }

  Future<void> _onPreferredCityChanged(String? city) async {
    switch (_selectedTab) {
      case HomeDiscoveryTab.sessions:
        final controller = ref.read(browseSessionsControllerProvider.notifier);
        final filters = ref.read(browseSessionsControllerProvider).filters;
        await controller.load(
          filters: city == null
              ? filters.copyWith(clearCity: true, cityIsDefault: true)
              : filters.copyWith(city: city, cityIsDefault: true),
        );
      case HomeDiscoveryTab.venues:
        final controller = ref.read(venueBrowseControllerProvider.notifier);
        final filter = ref.read(venueBrowseControllerProvider).filter;
        await controller.load(
          filter: city == null
              ? filter.copyWith(
                  clearCity: true,
                  clearDistrict: true,
                  cityIsDefault: true,
                )
              : filter.copyWith(
                  city: city,
                  clearDistrict: true,
                  cityIsDefault: true,
                ),
        );
      case HomeDiscoveryTab.clubs:
        final state = ref.read(clubsControllerProvider);
        await ref
            .read(clubsControllerProvider.notifier)
            .load(
              search: state.search,
              city: city,
              clearCity: city == null,
            );
      case HomeDiscoveryTab.tournaments:
        final state = ref.read(tournamentBrowseControllerProvider);
        await ref
            .read(tournamentBrowseControllerProvider.notifier)
            .load(
              search: state.search,
              city: city,
              clearCity: city == null,
            );
    }
  }

  PreferredSizeWidget _buildBrowseAppBar(
    BuildContext context,
    AppLocalizations l10n,
    bool isAuthenticated,
    bool canCreateTournament,
  ) => AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    flexibleSpace: const HomeHeaderBackdrop(),
    elevation: 0,
    scrolledUnderElevation: 0,
    leading: IconButton(
      tooltip: l10n.menuOpenTooltip,
      icon: const Icon(AppIcons.menu),
      onPressed: () =>
          ref.read(appShellScaffoldKeyProvider).currentState?.openDrawer(),
    ),
    title: Text(
      l10n.appName,
      style: Theme.of(context).appBarTheme.titleTextStyle?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    actions: [
      if (isAuthenticated) ...[
        ?_buildCreateAction(context, l10n, canCreateTournament),
        IconButton(
          key: const Key('home-search-button'),
          tooltip: l10n.homeSearchTooltip,
          icon: const Icon(AppIcons.search),
          onPressed: _openSearch,
        ),
        const NotificationHeaderButton(),
      ] else
        Tooltip(
          message: l10n.authSignIn,
          child: OutlinedButton.icon(
            key: const Key('home-sign-in-button'),
            icon: const Icon(AppIcons.login, size: 18),
            label: Text(l10n.authSignIn),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.32),
              ),
              visualDensity: VisualDensity.standard,
            ),
            onPressed: () => context.push(AppRoutes.signIn),
          ),
        ),
      const SizedBox(width: 8),
    ],
  );

  Widget? _buildCreateAction(
    BuildContext context,
    AppLocalizations l10n,
    bool canCreateTournament,
  ) => switch (_selectedTab) {
    HomeDiscoveryTab.sessions => IconButton(
      key: const Key('home-create-session-button'),
      tooltip: l10n.createSessionTitle,
      icon: const Icon(AppIcons.add),
      onPressed: () => context.push(AppRoutes.createSession),
    ),
    HomeDiscoveryTab.clubs => IconButton(
      key: const Key('home-create-club-button'),
      tooltip: l10n.clubCreate,
      icon: const Icon(AppIcons.add),
      onPressed: () => context.push(AppRoutes.createClub),
    ),
    HomeDiscoveryTab.tournaments when !canCreateTournament => null,
    HomeDiscoveryTab.tournaments => IconButton(
      key: const Key('home-create-tournament-button'),
      tooltip: l10n.tournamentCreate,
      icon: const Icon(AppIcons.add),
      onPressed: () => context.push(AppRoutes.createTournament),
    ),
    HomeDiscoveryTab.venues => null,
  };

  PreferredSizeWidget _buildSearchResultsAppBar(
    BuildContext context,
    AppLocalizations l10n,
    String query,
  ) => AppBar(
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    flexibleSpace: const HomeHeaderBackdrop(),
    elevation: 0,
    scrolledUnderElevation: 0,
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
    actions: const [SizedBox(width: 8)],
  );

  int _filterCount(
    BrowseSessionsState sessionState,
    VenueBrowseState venueState,
    ClubsState clubsState,
    TournamentBrowseState tournamentState,
    String? preferredCity,
  ) => switch (_selectedTab) {
    HomeDiscoveryTab.sessions => sessionState.filters.activeCount,
    HomeDiscoveryTab.venues => venueState.filter.activeCount(
      preferredCity: preferredCity,
    ),
    HomeDiscoveryTab.clubs => clubsState.activeFilterCount,
    HomeDiscoveryTab.tournaments => tournamentState.activeFilterCount,
  };

  String _sortLabel(
    AppLocalizations l10n,
    BrowseSessionsState sessionState,
    VenueBrowseState venueState,
    ClubsState clubsState,
    TournamentBrowseState tournamentState,
  ) => switch (_selectedTab) {
    HomeDiscoveryTab.sessions => _sessionSortLabel(
      l10n,
      sessionState.filters.sort,
    ),
    HomeDiscoveryTab.venues => VenueSortOption.fromValue(
      venueState.filter.sortBy,
    ).label(l10n),
    HomeDiscoveryTab.clubs => switch (clubsState.sortBy) {
      'name' => l10n.homeDiscoverySortNameAsc,
      'createdAt' => l10n.homeDiscoverySortNewest,
      _ => l10n.homeDiscoverySortPopular,
    },
    HomeDiscoveryTab.tournaments => switch (tournamentState.sort) {
      TournamentBrowseSort.startAsc => l10n.homeDiscoverySortStartSoonest,
      TournamentBrowseSort.newest => l10n.homeDiscoverySortNewest,
      TournamentBrowseSort.nameAsc => l10n.homeDiscoverySortNameAsc,
      TournamentBrowseSort.nameDesc => l10n.homeDiscoverySortNameDesc,
    },
  };

  bool _hasCustomSort(
    BrowseSessionsState sessionState,
    VenueBrowseState venueState,
    ClubsState clubsState,
    TournamentBrowseState tournamentState,
  ) => switch (_selectedTab) {
    HomeDiscoveryTab.sessions =>
      sessionState.filters.sort != SessionBrowseSort.dateAsc,
    HomeDiscoveryTab.venues =>
      venueState.filter.sortBy != VenueSortOption.distance.value,
    HomeDiscoveryTab.clubs => clubsState.sortBy != 'sessionCount',
    HomeDiscoveryTab.tournaments =>
      tournamentState.sort != TournamentBrowseSort.startAsc,
  };

  IconData _sortIcon(
    BrowseSessionsState sessionState,
    VenueBrowseState venueState,
    ClubsState clubsState,
    TournamentBrowseState tournamentState,
  ) => switch (_selectedTab) {
    HomeDiscoveryTab.sessions => _sessionSortIcon(sessionState.filters.sort),
    HomeDiscoveryTab.venues => VenueSortOption.fromValue(
      venueState.filter.sortBy,
    ).icon,
    HomeDiscoveryTab.clubs => switch (clubsState.sortBy) {
      'name' => AppIcons.sortAlpha,
      'createdAt' => AppIcons.calendarArrowDown,
      _ => AppIcons.trendingUp,
    },
    HomeDiscoveryTab.tournaments => switch (tournamentState.sort) {
      TournamentBrowseSort.startAsc => AppIcons.calendarClock,
      TournamentBrowseSort.newest => AppIcons.calendarArrowDown,
      TournamentBrowseSort.nameAsc => AppIcons.sortAlpha,
      TournamentBrowseSort.nameDesc => AppIcons.sortAlphaDesc,
    },
  };

  IconData _sessionSortIcon(SessionBrowseSort sort) => switch (sort) {
    SessionBrowseSort.dateAsc => AppIcons.calendarClock,
    SessionBrowseSort.dateDesc => AppIcons.calendarArrowDown,
    SessionBrowseSort.newest => AppIcons.history,
    SessionBrowseSort.priceAsc => AppIcons.sortNumberAsc,
    SessionBrowseSort.priceDesc => AppIcons.sortNumberDesc,
  };

  String _sessionSortLabel(
    AppLocalizations l10n,
    SessionBrowseSort sort,
  ) => switch (sort) {
    SessionBrowseSort.dateAsc => l10n.homeDiscoverySortDateNearest,
    SessionBrowseSort.dateDesc => l10n.homeDiscoverySortDateFurthest,
    SessionBrowseSort.newest => l10n.homeDiscoverySortNewest,
    SessionBrowseSort.priceAsc => l10n.homeDiscoverySortPriceLow,
    SessionBrowseSort.priceDesc => l10n.homeDiscoverySortPriceHigh,
  };

  Future<void> _openActiveSort() async {
    final l10n = AppLocalizations.of(context);
    switch (_selectedTab) {
      case HomeDiscoveryTab.sessions:
        final controller = ref.read(browseSessionsControllerProvider.notifier);
        final current = ref.read(browseSessionsControllerProvider).filters;
        final selected = await showAppSortSheet<SessionBrowseSort>(
          context,
          title: l10n.homeDiscoverySortBy,
          selected: current.sort,
          options: [
            for (final option in SessionBrowseSort.values)
              AppSortOption(
                value: option,
                label: _sessionSortLabel(l10n, option),
                icon: _sessionSortIcon(option),
              ),
          ],
        );
        if (selected != null) {
          unawaited(controller.load(filters: current.copyWith(sort: selected)));
        }
      case HomeDiscoveryTab.venues:
        final controller = ref.read(venueBrowseControllerProvider.notifier);
        final current = ref.read(venueBrowseControllerProvider).filter;
        final selected = await showAppSortSheet<VenueSortOption>(
          context,
          title: l10n.homeDiscoverySortBy,
          selected: VenueSortOption.fromValue(current.sortBy),
          options: [
            for (final option in VenueSortOption.values)
              AppSortOption(
                value: option,
                label: option.label(l10n),
                icon: option.icon,
              ),
          ],
        );
        if (selected != null) {
          var next = current.copyWith(
            sortBy: selected.value,
            clearLocation: selected != VenueSortOption.distance,
          );
          if (selected == VenueSortOption.distance &&
              (current.latitude == null || current.longitude == null)) {
            try {
              final coordinates = await ref
                  .read(deviceLocationServiceProvider)
                  .call();
              next = next.copyWith(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude,
              );
            } on Object {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.venueFilterLocationDenied)),
                );
              }
              return;
            }
          }
          unawaited(controller.load(filter: next));
        }
      case HomeDiscoveryTab.clubs:
        final controller = ref.read(clubsControllerProvider.notifier);
        final current = ref.read(clubsControllerProvider);
        final selected = await showAppSortSheet<String>(
          context,
          title: l10n.homeDiscoverySortBy,
          selected: current.sortBy,
          options: [
            AppSortOption(
              value: 'sessionCount',
              label: l10n.homeDiscoverySortPopular,
              icon: AppIcons.trendingUp,
            ),
            AppSortOption(
              value: 'createdAt',
              label: l10n.homeDiscoverySortNewest,
              icon: AppIcons.calendarArrowDown,
            ),
            AppSortOption(
              value: 'name',
              label: l10n.homeDiscoverySortNameAsc,
              icon: AppIcons.sortAlpha,
            ),
          ],
        );
        if (selected != null) {
          unawaited(controller.load(search: current.search, sortBy: selected));
        }
      case HomeDiscoveryTab.tournaments:
        final controller = ref.read(
          tournamentBrowseControllerProvider.notifier,
        );
        final current = ref.read(tournamentBrowseControllerProvider);
        final selected = await showAppSortSheet<TournamentBrowseSort>(
          context,
          title: l10n.homeDiscoverySortBy,
          selected: current.sort,
          options: [
            AppSortOption(
              value: TournamentBrowseSort.startAsc,
              label: l10n.homeDiscoverySortStartSoonest,
              icon: AppIcons.calendarClock,
            ),
            AppSortOption(
              value: TournamentBrowseSort.newest,
              label: l10n.homeDiscoverySortNewest,
              icon: AppIcons.calendarArrowDown,
            ),
            AppSortOption(
              value: TournamentBrowseSort.nameAsc,
              label: l10n.homeDiscoverySortNameAsc,
              icon: AppIcons.sortAlpha,
            ),
            AppSortOption(
              value: TournamentBrowseSort.nameDesc,
              label: l10n.homeDiscoverySortNameDesc,
              icon: AppIcons.sortAlphaDesc,
            ),
          ],
        );
        if (selected != null) {
          unawaited(controller.load(sort: selected));
        }
    }
  }

  Future<void> _openActiveFilters() => switch (_selectedTab) {
    HomeDiscoveryTab.sessions => _openSessionFilters(),
    HomeDiscoveryTab.venues => _openVenueFilters(),
    HomeDiscoveryTab.clubs => _openClubFilters(),
    HomeDiscoveryTab.tournaments => _openTournamentFilters(),
  };

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

  Future<void> _openClubFilters() async {
    final controller = ref.read(clubsControllerProvider.notifier);
    final current = ref.read(clubsControllerProvider);
    final filter = await showModalBottomSheet<ClubDiscoveryFilters>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ClubDiscoveryFilterSheet(
        initial: ClubDiscoveryFilters(
          district: current.district,
          favoriteOnly: current.favoriteOnly,
        ),
      ),
    );
    if (filter == null) return;
    unawaited(
      controller.load(
        search: current.search,
        district: filter.district,
        clearDistrict: filter.district == null,
        favoriteOnly: filter.favoriteOnly,
      ),
    );
  }

  Future<void> _openTournamentFilters() async {
    final controller = ref.read(tournamentBrowseControllerProvider.notifier);
    final current = ref.read(tournamentBrowseControllerProvider);
    final filter = await showModalBottomSheet<TournamentDiscoveryFilters>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => TournamentDiscoveryFilterSheet(
        initial: TournamentDiscoveryFilters(
          statuses: current.statuses,
          sportTypes: current.sportTypes,
          favoriteOnly: current.favoriteOnly,
        ),
      ),
    );
    if (filter == null) return;
    unawaited(
      controller.load(
        statuses: filter.statuses,
        sportTypes: filter.sportTypes,
        favoriteOnly: filter.favoriteOnly,
      ),
    );
  }
}
