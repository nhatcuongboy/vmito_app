import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';

export 'package:vmito_app/features/session/domain/browse_session_filters.dart';

/// What the browse list renders.
class BrowseSessionsState {
  const BrowseSessionsState({
    this.sessions = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.mapSessions = const [],
    this.isMapLoading = false,
    this.mapError,
    this.error,
    this.page = 0,
    this.totalPages = 0,
    this.filters = const BrowseSessionFilters(),
  });

  final List<Session> sessions;
  final bool isLoading;
  final bool isLoadingMore;
  final List<Session> mapSessions;
  final bool isMapLoading;
  final ApiException? mapError;
  final ApiException? error;
  final int page;
  final int totalPages;
  final BrowseSessionFilters filters;

  String? get search => filters.search.isEmpty ? null : filters.search;

  bool get hasMore => page > 0 && page < totalPages;

  /// True only once loading has finished and nothing came back — so the empty
  /// state never flashes during the first fetch.
  bool get isEmpty => !isLoading && error == null && sessions.isEmpty;

  BrowseSessionsState copyWith({
    List<Session>? sessions,
    bool? isLoading,
    bool? isLoadingMore,
    List<Session>? mapSessions,
    bool? isMapLoading,
    ApiException? mapError,
    ApiException? error,
    int? page,
    int? totalPages,
    BrowseSessionFilters? filters,
    bool clearError = false,
    bool clearMap = false,
    bool clearMapError = false,
  }) => BrowseSessionsState(
    sessions: sessions ?? this.sessions,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    mapSessions: clearMap ? const [] : mapSessions ?? this.mapSessions,
    isMapLoading: isMapLoading ?? this.isMapLoading,
    mapError: clearMap || clearMapError ? null : mapError ?? this.mapError,
    error: clearError ? null : error ?? this.error,
    page: page ?? this.page,
    totalPages: totalPages ?? this.totalPages,
    filters: filters ?? this.filters,
  );
}

/// Owns the browse list: first page, pagination, refresh and search.
class BrowseSessionsController extends Notifier<BrowseSessionsState> {
  @override
  BrowseSessionsState build() => const BrowseSessionsState();

  SessionRepository get _repo => ref.read(sessionRepositoryProvider);

  static const _pageSize = 20;
  static const _mapPageSize = 500;

  // Snapshot restoration is an action, not a property mutation API.
  // ignore: use_setters_to_change_properties
  void restore(BrowseSessionsState snapshot) => state = snapshot;

  /// Loads page 1, replacing whatever is on screen.
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    final nextFilters =
        filters ??
        (search == null
            ? state.filters
            : state.filters.copyWith(search: search));
    final filtersChanged = nextFilters != state.filters;
    state = state.copyWith(
      isLoading: true,
      isMapLoading: !filtersChanged && state.isMapLoading,
      clearError: true,
      filters: nextFilters,
      clearMap: filtersChanged,
    );
    await _fetch(page: 1, replace: true);
  }

  /// Pull-to-refresh. Keeps the current list visible while it runs, so the
  /// screen never blanks under the user.
  Future<void> refresh() => _fetch(page: 1, replace: true);

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    await _fetch(page: state.page + 1, replace: false);
  }

  /// Fetches the complete filtered result set used by the map. The normal
  /// list remains paginated so opening Home stays lightweight.
  Future<void> loadMap() async {
    if (state.isMapLoading) return;
    final filters = state.filters;
    state = state.copyWith(isMapLoading: true, clearMapError: true);
    try {
      final result = await _browse(
        filters: filters,
        page: 1,
        limit: _mapPageSize,
      );
      if (state.filters != filters) return;
      state = state.copyWith(
        mapSessions: result.items,
        isMapLoading: false,
        clearMapError: true,
      );
    } on ApiException catch (error) {
      if (state.filters != filters) return;
      state = state.copyWith(
        isMapLoading: false,
        mapError: error,
      );
    }
  }

  Future<void> _fetch({required int page, required bool replace}) async {
    try {
      final result = await _browse(
        filters: state.filters,
        page: page,
        limit: _pageSize,
      );
      state = state.copyWith(
        sessions: replace ? result.items : [...state.sessions, ...result.items],
        isLoading: false,
        isLoadingMore: false,
        page: result.page,
        totalPages: result.totalPages,
        clearError: true,
      );
      AppLogger.debug(
        '[Tìm kèo] loaded page=${result.page}/${result.totalPages}, items=${result.items.length}, total=${result.total}',
      );
    } on ApiException catch (error) {
      AppLogger.warn('[Tìm kèo] API request failed', error: error);
      // A failed "load more" must not discard the pages already on screen.
      state = state.copyWith(
        sessions: replace ? const [] : state.sessions,
        isLoading: false,
        isLoadingMore: false,
        error: error,
      );
    }
  }

  Future<Page<Session>> _browse({
    required BrowseSessionFilters filters,
    required int page,
    required int limit,
  }) => _repo.browseAvailable(
    page: page,
    limit: limit,
    search: filters.search,
    date: filters.date,
    timeRanges: filters.timeRanges,
    levels: filters.levels,
    sports: filters.sports,
    hasSlots: filters.hasSlots ? true : null,
    sessionType: filters.source.name,
    city: filters.city,
    districts: filters.districts,
    minFee: filters.hasCustomFeeRange ? filters.minFee : null,
    maxFee: filters.hasCustomFeeRange ? filters.maxFee : null,
    splitEvenly: filters.splitEvenly,
    latitude: filters.nearMe ? filters.latitude : null,
    longitude: filters.nearMe ? filters.longitude : null,
    sortByDistance: filters.nearMe,
    venueId: filters.venueId,
    sortBy: filters.sort.sortBy,
    sortOrder: filters.sort.sortOrder,
  );
}

final browseSessionsControllerProvider =
    NotifierProvider<BrowseSessionsController, BrowseSessionsState>(
      BrowseSessionsController.new,
    );
