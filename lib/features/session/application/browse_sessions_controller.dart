import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/features/session/data/session_service.dart';
import 'package:vmito_app/features/session/domain/session.dart';

enum SessionSource { all, regular, facebook }

class BrowseSessionFilters {
  const BrowseSessionFilters({
    this.search = '',
    this.level,
    this.hasSlots = false,
    this.source = SessionSource.all,
  });

  final String search;
  final int? level;
  final bool hasSlots;
  final SessionSource source;

  int get activeCount =>
      (level == null ? 0 : 1) +
      (hasSlots ? 1 : 0) +
      (source == SessionSource.all ? 0 : 1);

  BrowseSessionFilters copyWith({
    String? search,
    bool? hasSlots,
    SessionSource? source,
  }) => BrowseSessionFilters(
    search: search ?? this.search,
    level: level,
    hasSlots: hasSlots ?? this.hasSlots,
    source: source ?? this.source,
  );

  BrowseSessionFilters withLevel(int? value) => BrowseSessionFilters(
    search: search,
    level: value,
    hasSlots: hasSlots,
    source: source,
  );
}

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

  SessionService get _service => ref.read(sessionServiceProvider);

  static const _pageSize = 20;

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
      final result = await _service.browseAvailable(
        page: page,
        limit: _pageSize,
        search: state.filters.search,
        level: state.filters.level,
        hasSlots: state.filters.hasSlots ? true : null,
        sessionType: state.filters.source.name,
      );
      state = BrowseSessionsState(
        sessions: replace ? result.items : [...state.sessions, ...result.items],
        page: result.page,
        totalPages: result.totalPages,
        filters: state.filters,
      );
    } on ApiException catch (error) {
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
