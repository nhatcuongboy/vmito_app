import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_standings_preferences.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_standings.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentStandingsState {
  const TournamentStandingsState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.matches = const [],
    this.standingsByCategory = const {},
    this.stage = TournamentStandingsStage.pool,
    this.view = TournamentStandingsView.pools,
    this.showPlayerNames = false,
    this.currentUserId,
    this.currentUserRole,
    this.selectedCategoryId,
    this.recalculatingGroupId,
    this.tournament,
    this.error,
  });

  final bool isLoading;
  final bool hasLoaded;
  final TournamentDetail? tournament;
  final List<TournamentMatch> matches;
  final Map<String, List<TournamentStandingGroup>> standingsByCategory;
  final TournamentStandingsStage stage;
  final TournamentStandingsView view;
  final bool showPlayerNames;
  final String? currentUserId;
  final UserRole? currentUserRole;
  final String? selectedCategoryId;
  final String? recalculatingGroupId;
  final Object? error;

  bool get canManage =>
      tournament != null &&
      (currentUserRole == UserRole.admin ||
          currentUserId == tournament!.hostId);

  List<TournamentCategory> get visibleCategories {
    final categories = tournament?.categories ?? const <TournamentCategory>[];
    if (selectedCategoryId == null) return categories;
    return categories
        .where((category) => category.id == selectedCategoryId)
        .toList(growable: false);
  }

  bool get hasAnyStandings => standingsByCategory.values.any(
    (groups) => groups.any((group) => group.rows.isNotEmpty),
  );

  TournamentStandingsState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    TournamentDetail? tournament,
    List<TournamentMatch>? matches,
    Map<String, List<TournamentStandingGroup>>? standingsByCategory,
    TournamentStandingsStage? stage,
    TournamentStandingsView? view,
    bool? showPlayerNames,
    String? currentUserId,
    UserRole? currentUserRole,
    Object? selectedCategoryId = _unset,
    Object? recalculatingGroupId = _unset,
    Object? error = _unset,
  }) => TournamentStandingsState(
    isLoading: isLoading ?? this.isLoading,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    tournament: tournament ?? this.tournament,
    matches: matches ?? this.matches,
    standingsByCategory: standingsByCategory ?? this.standingsByCategory,
    stage: stage ?? this.stage,
    view: view ?? this.view,
    showPlayerNames: showPlayerNames ?? this.showPlayerNames,
    currentUserId: currentUserId ?? this.currentUserId,
    currentUserRole: currentUserRole ?? this.currentUserRole,
    selectedCategoryId: identical(selectedCategoryId, _unset)
        ? this.selectedCategoryId
        : selectedCategoryId as String?,
    recalculatingGroupId: identical(recalculatingGroupId, _unset)
        ? this.recalculatingGroupId
        : recalculatingGroupId as String?,
    error: identical(error, _unset) ? this.error : error,
  );
}

const _unset = Object();

class TournamentStandingsController extends Notifier<TournamentStandingsState> {
  TournamentStandingsController(this.idOrSlug);

  final String idOrSlug;
  Timer? _refreshDebounce;
  StreamSubscription<SocketEvent>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  SocketClient? _socket;
  String? _joinedTournamentId;
  bool _connectedOnce = false;

  TournamentService get _service => ref.read(tournamentServiceProvider);

  @override
  TournamentStandingsState build() {
    final user = ref.watch(authControllerProvider).user;
    ref.onDispose(() {
      _refreshDebounce?.cancel();
      unawaited(_eventSubscription?.cancel());
      unawaited(_connectionSubscription?.cancel());
      if (_joinedTournamentId case final tournamentId?) {
        _socket?.leaveTournament(tournamentId);
      }
    });
    return TournamentStandingsState(
      currentUserId: user?.id,
      currentUserRole: user?.role,
    );
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading || (state.hasLoaded && !force)) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tournament = await _service.detail(idOrSlug);
      final results = await Future.wait<Object>([
        _service.matches(tournament.id),
        _loadStandings(tournament.categories),
        ref.read(tournamentStandingsPreferencesProvider).readShowPlayerNames(),
      ]);
      final user = ref.read(authControllerProvider).user;
      final validSelection = tournament.categories.any(
        (category) => category.id == state.selectedCategoryId,
      );
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        tournament: tournament,
        matches: results[0] as List<TournamentMatch>,
        standingsByCategory:
            results[1] as Map<String, List<TournamentStandingGroup>>,
        showPlayerNames: results[2] as bool,
        currentUserId: user?.id,
        currentUserRole: user?.role,
        selectedCategoryId: validSelection ? state.selectedCategoryId : null,
        error: null,
      );
      _startRealtime(tournament);
    } on Object catch (error) {
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        error: error,
      );
    }
  }

  Future<Map<String, List<TournamentStandingGroup>>> _loadStandings(
    List<TournamentCategory> categories,
  ) async => Map.fromEntries(
    await Future.wait([
      for (final category in categories)
        _service
            .standings(category.id)
            .then((groups) => MapEntry(category.id, groups)),
    ]),
  );

  void selectCategory(String? categoryId) {
    if (categoryId == state.selectedCategoryId) return;
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void setStage(TournamentStandingsStage stage) {
    if (stage == state.stage) return;
    state = state.copyWith(stage: stage);
  }

  void setView(TournamentStandingsView view) {
    if (view == state.view) return;
    state = state.copyWith(view: view);
  }

  Future<void> setShowPlayerNames({required bool value}) async {
    if (value == state.showPlayerNames) return;
    state = state.copyWith(showPlayerNames: value);
    await ref
        .read(tournamentStandingsPreferencesProvider)
        .writeShowPlayerNames(value: value);
  }

  Future<void> refresh() => _refreshSnapshot(exposeError: true);

  Future<void> _refreshSnapshot({required bool exposeError}) async {
    final tournament = state.tournament;
    if (tournament == null) return load(force: true);
    try {
      final results = await Future.wait<Object>([
        _service.matches(tournament.id),
        _loadStandings(tournament.categories),
      ]);
      state = state.copyWith(
        matches: results[0] as List<TournamentMatch>,
        standingsByCategory:
            results[1] as Map<String, List<TournamentStandingGroup>>,
        error: null,
      );
    } on Object catch (error) {
      if (exposeError) state = state.copyWith(error: error);
    }
  }

  Future<void> recalculate(String categoryId, String groupId) async {
    if (!state.canManage || state.recalculatingGroupId != null) return;
    state = state.copyWith(recalculatingGroupId: groupId);
    try {
      await _service.calculateStandings(categoryId, groupId);
      final groups = await _service.standings(categoryId);
      state = state.copyWith(
        standingsByCategory: {
          ...state.standingsByCategory,
          categoryId: groups,
        },
        error: null,
      );
    } finally {
      state = state.copyWith(recalculatingGroupId: null);
    }
  }

  void _startRealtime(TournamentDetail tournament) {
    if (tournament.status == TournamentStatus.finished ||
        tournament.status == TournamentStatus.cancelled ||
        _socket != null) {
      return;
    }
    final socket = ref.read(tournamentSocketClientProvider(idOrSlug));
    _socket = socket..connect();
    _joinedTournamentId = tournament.id;
    socket.joinTournament(tournament.id);
    _eventSubscription = socket.events
        .where((event) => event.data['tournamentId'] == tournament.id)
        .listen((event) {
          if (event.name == TournamentEvent.ended) {
            _scheduleRefresh();
            socket.leaveTournament(tournament.id);
            return;
          }
          if (event.name == TournamentEvent.scoreUpdated ||
              event.name == TournamentEvent.matchStarted ||
              event.name == TournamentEvent.matchEnded) {
            _scheduleRefresh();
          }
        });
    _connectionSubscription = socket.connectionState.listen((connected) {
      if (connected && _connectedOnce) {
        unawaited(_refreshSnapshot(exposeError: false));
      }
      if (connected) _connectedOnce = true;
    });
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_refreshSnapshot(exposeError: false)),
    );
  }
}

final NotifierProviderFamily<
  TournamentStandingsController,
  TournamentStandingsState,
  String
>
tournamentStandingsControllerProvider =
    NotifierProvider.family<
      TournamentStandingsController,
      TournamentStandingsState,
      String
    >(TournamentStandingsController.new);
