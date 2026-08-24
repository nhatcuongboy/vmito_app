import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
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
    this.error,
    this.page = 0,
    this.totalPages = 0,
    this.filters = const BrowseSessionFilters(),
  });

  final List<Session> sessions;
  final bool isLoading;
  final bool isLoadingMore;
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
    int? page,
    int? totalPages,
    BrowseSessionFilters? filters,
    bool clearError = false,
  }) => BrowseSessionsState(
    sessions: sessions ?? this.sessions,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    error: clearError ? null : error,
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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      filters: nextFilters,
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

  Future<void> _fetch({required int page, required bool replace}) async {
    try {
      final result = await _repo.browseAvailable(
        page: page,
        limit: _pageSize,
        search: state.filters.search,
        date: state.filters.date,
        timeRanges: state.filters.timeRanges,
        levels: state.filters.levels,
        sports: state.filters.sports,
        hasSlots: state.filters.hasSlots ? true : null,
        sessionType: state.filters.source.name,
        city: state.filters.city,
        districts: state.filters.districts,
        minFee: state.filters.hasCustomFeeRange ? state.filters.minFee : null,
        maxFee: state.filters.hasCustomFeeRange ? state.filters.maxFee : null,
        splitEvenly: state.filters.splitEvenly,
        latitude: state.filters.nearMe ? state.filters.latitude : null,
        longitude: state.filters.nearMe ? state.filters.longitude : null,
        sortByDistance: state.filters.nearMe,
        venueId: state.filters.venueId,
      );
      state = BrowseSessionsState(
        sessions: replace ? result.items : [...state.sessions, ...result.items],
        page: result.page,
        totalPages: result.totalPages,
        filters: state.filters,
      );
      AppLogger.debug(
        '[Tìm kèo] loaded page=${result.page}/${result.totalPages}, items=${result.items.length}, total=${result.total}',
      );
    } on ApiException catch (error) {
      AppLogger.warn('[Tìm kèo] API request failed', error: error);
      // A failed "load more" must not discard the pages already on screen.
      state = BrowseSessionsState(
        sessions: replace ? const [] : state.sessions,
        page: state.page,
        totalPages: state.totalPages,
        filters: state.filters,
        error: error,
      );
    }
  }
}

final browseSessionsControllerProvider =
    NotifierProvider<BrowseSessionsController, BrowseSessionsState>(
      BrowseSessionsController.new,
    );
