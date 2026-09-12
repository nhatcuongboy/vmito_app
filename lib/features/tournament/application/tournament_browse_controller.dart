import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

enum TournamentBrowseSort {
  startAsc('startDate', 'asc'),
  newest('createdAt', 'desc'),
  nameAsc('name', 'asc'),
  nameDesc('name', 'desc');

  const TournamentBrowseSort(this.sortBy, this.sortOrder);

  final String sortBy;
  final String sortOrder;
}

class TournamentBrowseState {
  const TournamentBrowseState({
    this.tournaments = const [],
    this.search = '',
    this.city,
    this.statuses = const {TournamentStatus.preparing},
    this.sportTypes = const {},
    this.favoriteOnly = false,
    this.sort = TournamentBrowseSort.startAsc,
    this.isLoading = false,
    this.isRefetching = false,
    this.error,
  });

  final List<TournamentSummary> tournaments;
  final String search;
  final String? city;
  final Set<TournamentStatus> statuses;
  final Set<String> sportTypes;
  final bool favoriteOnly;
  final TournamentBrowseSort sort;
  final bool isLoading;

  /// True while a search/sort/filter change is refetching the list that
  /// already has items on screen — distinct from [isLoading], which only
  /// covers the first fetch (nothing rendered yet).
  final bool isRefetching;
  final Object? error;

  int get activeFilterCount =>
      (statuses.length == 1 && statuses.contains(TournamentStatus.preparing)
          ? 0
          : 1) +
      (sportTypes.isEmpty ? 0 : 1) +
      (favoriteOnly ? 1 : 0);
}

class TournamentBrowseController extends Notifier<TournamentBrowseState> {
  @override
  TournamentBrowseState build() => const TournamentBrowseState();

  // Snapshot restoration is an action, not a property mutation API.
  // ignore: use_setters_to_change_properties
  void restore(TournamentBrowseState snapshot) => state = snapshot;

  Future<void> load({
    String? search,
    String? city,
    bool clearCity = false,
    Set<TournamentStatus>? statuses,
    Set<String>? sportTypes,
    bool? favoriteOnly,
    TournamentBrowseSort? sort,
    bool isPullToRefresh = false,
  }) async {
    final activeSearch = search ?? state.search;
    final activeCity = clearCity ? null : city ?? state.city;
    final activeStatuses = statuses ?? state.statuses;
    final activeSportTypes = sportTypes ?? state.sportTypes;
    final activeFavoriteOnly = favoriteOnly ?? state.favoriteOnly;
    final activeSort = sort ?? state.sort;
    final hasExisting = state.tournaments.isNotEmpty;
    state = TournamentBrowseState(
      tournaments: state.tournaments,
      search: activeSearch,
      city: activeCity,
      statuses: activeStatuses,
      sportTypes: activeSportTypes,
      favoriteOnly: activeFavoriteOnly,
      sort: activeSort,
      isLoading: !hasExisting,
      isRefetching: !isPullToRefresh && hasExisting,
    );
    try {
      final tournaments = await ref
          .read(tournamentServiceProvider)
          .browse(
            search: activeSearch,
            city: activeCity,
            statuses: activeStatuses,
            sportTypes: activeSportTypes,
            favoriteOnly: activeFavoriteOnly,
            sortBy: activeSort.sortBy,
            sortOrder: activeSort.sortOrder,
          );
      state = TournamentBrowseState(
        tournaments: tournaments,
        search: activeSearch,
        city: activeCity,
        statuses: activeStatuses,
        sportTypes: activeSportTypes,
        favoriteOnly: activeFavoriteOnly,
        sort: activeSort,
      );
    } on Object catch (error) {
      state = TournamentBrowseState(
        search: activeSearch,
        city: activeCity,
        statuses: activeStatuses,
        sportTypes: activeSportTypes,
        favoriteOnly: activeFavoriteOnly,
        sort: activeSort,
        error: error,
      );
    }
  }
}

final tournamentBrowseControllerProvider =
    NotifierProvider<TournamentBrowseController, TournamentBrowseState>(
      TournamentBrowseController.new,
    );
