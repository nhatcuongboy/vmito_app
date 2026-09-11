import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_management_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

/// The three status buckets of the web host list (`HostTournamentsHeader`).
///
/// Buckets group the raw server status, so an overdue IN_PROGRESS tournament
/// still counts as open — the same as web.
enum HostTournamentTab {
  open({TournamentStatus.preparing, TournamentStatus.inProgress}),
  ended({TournamentStatus.finished, TournamentStatus.cancelled}),
  all({});

  const HostTournamentTab(this.statuses);

  final Set<TournamentStatus> statuses;

  bool includes(TournamentStatus status) =>
      statuses.isEmpty || statuses.contains(status);
}

class HostTournamentsState {
  const HostTournamentsState({
    this.tournaments = const [],
    this.hasLoaded = false,
    this.isLoading = false,
    this.error,
    this.tab = HostTournamentTab.open,
    this.sort = TournamentBrowseSort.startAsc,
    this.query = '',
    this.deletingId,
  });

  /// Everything the server returned. The endpoint is unpaginated, so search,
  /// tab and sort all run on the device, as on web.
  final List<TournamentSummary> tournaments;
  final bool hasLoaded;
  final bool isLoading;
  final Object? error;
  final HostTournamentTab tab;
  final TournamentBrowseSort sort;
  final String query;
  final String? deletingId;

  bool get isFiltered => query.isNotEmpty || tab != HostTournamentTab.all;

  List<TournamentSummary> get visible {
    final needle = query.toLowerCase();
    final items = tournaments
        .where((item) => tab.includes(item.status))
        .where(
          (item) => needle.isEmpty || item.name.toLowerCase().contains(needle),
        )
        .toList();
    int byName(TournamentSummary a, TournamentSummary b) =>
        a.name.toLowerCase().compareTo(b.name.toLowerCase());
    items.sort(
      switch (sort) {
        TournamentBrowseSort.startAsc => (a, b) => a.startDate.compareTo(
          b.startDate,
        ),
        TournamentBrowseSort.newest =>
          (a, b) => (b.createdAt ?? b.startDate).compareTo(
            a.createdAt ?? a.startDate,
          ),
        TournamentBrowseSort.nameAsc => byName,
        TournamentBrowseSort.nameDesc => (a, b) => byName(b, a),
      },
    );
    return items;
  }

  HostTournamentsState copyWith({
    List<TournamentSummary>? tournaments,
    bool? hasLoaded,
    bool? isLoading,
    Object? error,
    bool clearError = false,
    HostTournamentTab? tab,
    TournamentBrowseSort? sort,
    String? query,
    String? deletingId,
    bool clearDeleting = false,
  }) => HostTournamentsState(
    tournaments: tournaments ?? this.tournaments,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : error ?? this.error,
    tab: tab ?? this.tab,
    sort: sort ?? this.sort,
    query: query ?? this.query,
    deletingId: clearDeleting ? null : deletingId ?? this.deletingId,
  );
}

class HostTournamentsController extends Notifier<HostTournamentsState> {
  int _requestVersion = 0;

  @override
  HostTournamentsState build() => const HostTournamentsState();

  Future<void> loadInitial() async {
    if (!state.hasLoaded && !state.isLoading) await _load();
  }

  /// Keeps the current list on screen while reloading; a failure is surfaced
  /// through [HostTournamentsState.error] without clearing loaded content.
  Future<void> refresh() => _load(silent: state.hasLoaded);

  void setTab(HostTournamentTab tab) => state = state.copyWith(tab: tab);

  void setSort(TournamentBrowseSort sort) => state = state.copyWith(sort: sort);

  void setSearch(String query) => state = state.copyWith(query: query.trim());

  /// Deletes on the server, then drops the row locally — no refetch, as web.
  /// Rethrows so the screen can report the failure.
  Future<void> delete(String id) async {
    if (state.deletingId != null) return;
    state = state.copyWith(deletingId: id);
    try {
      await ref.read(tournamentManagementServiceProvider).deleteTournament(id);
      state = state.copyWith(
        tournaments: [
          for (final item in state.tournaments)
            if (item.id != id) item,
        ],
        clearDeleting: true,
      );
      ref.invalidate(tournamentBrowseControllerProvider);
    } on Object {
      state = state.copyWith(clearDeleting: true);
      rethrow;
    }
  }

  Future<void> _load({bool silent = false}) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      state = state.copyWith(tournaments: const [], hasLoaded: true);
      return;
    }
    final version = ++_requestVersion;
    state = state.copyWith(isLoading: !silent, clearError: true);
    try {
      final service = ref.read(tournamentServiceProvider);
      final items = user.isAdmin
          ? await service.manageable()
          : await service.mine();
      if (version != _requestVersion) return;
      state = state.copyWith(
        tournaments: items,
        hasLoaded: true,
        isLoading: false,
      );
    } on Object catch (error) {
      if (version != _requestVersion) return;
      state = state.copyWith(isLoading: false, error: error);
    }
  }
}

// Riverpod's generated provider type is intentionally inferred at the boundary.
// ignore: specify_nonobvious_property_types
final hostTournamentsControllerProvider =
    NotifierProvider.autoDispose<
      HostTournamentsController,
      HostTournamentsState
    >(HostTournamentsController.new);
