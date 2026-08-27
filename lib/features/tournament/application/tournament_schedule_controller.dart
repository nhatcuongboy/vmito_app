import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/tournament/data/tournament_schedule_preferences.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentScheduleState {
  const TournamentScheduleState({
    this.isLoading = false,
    this.hasLoaded = false,
    this.matches = const [],
    this.courts = const [],
    this.groups = const [],
    this.umpires = const [],
    this.ownAssignmentIds = const {},
    this.filters = const TournamentScheduleFilters(),
    this.viewMode = TournamentScheduleViewMode.list,
    this.visibleCount = 50,
    this.showPlayerNames = false,
    this.busyMatchIds = const {},
    this.busyCategoryIds = const {},
    this.currentUserId,
    this.currentUserRole,
    this.tournament,
    this.error,
    this.courtsError,
    this.groupsError,
    this.umpiresError,
  });

  final bool isLoading;
  final bool hasLoaded;
  final TournamentDetail? tournament;
  final List<TournamentMatch> matches;
  final List<TournamentCourt> courts;
  final List<TournamentCategoryGroup> groups;
  final List<TournamentUmpire> umpires;
  final Set<String> ownAssignmentIds;
  final TournamentScheduleFilters filters;
  final TournamentScheduleViewMode viewMode;
  final int visibleCount;
  final bool showPlayerNames;
  final Set<String> busyMatchIds;
  final Set<String> busyCategoryIds;
  final String? currentUserId;
  final UserRole? currentUserRole;
  final Object? error;
  final Object? courtsError;
  final Object? groupsError;
  final Object? umpiresError;

  bool get canEdit =>
      tournament != null &&
      (currentUserRole == UserRole.admin ||
          currentUserId == tournament!.hostId);
  bool get canRefereeAny => canEdit || currentUserRole == UserRole.referee;
  bool isBusy(String matchId) => busyMatchIds.contains(matchId);

  List<TournamentMatch> get filteredMatches => filterAndSortTournamentMatches(
    matches,
    filters,
    currentUserId: currentUserId,
    canRefereeAny: canRefereeAny,
    ownAssignmentIds: ownAssignmentIds,
  );

  TournamentScheduleState copyWith({
    bool? isLoading,
    bool? hasLoaded,
    TournamentDetail? tournament,
    List<TournamentMatch>? matches,
    List<TournamentCourt>? courts,
    List<TournamentCategoryGroup>? groups,
    List<TournamentUmpire>? umpires,
    Set<String>? ownAssignmentIds,
    TournamentScheduleFilters? filters,
    TournamentScheduleViewMode? viewMode,
    int? visibleCount,
    bool? showPlayerNames,
    Set<String>? busyMatchIds,
    Set<String>? busyCategoryIds,
    String? currentUserId,
    UserRole? currentUserRole,
    Object? error = _unset,
    Object? courtsError = _unset,
    Object? groupsError = _unset,
    Object? umpiresError = _unset,
  }) => TournamentScheduleState(
    isLoading: isLoading ?? this.isLoading,
    hasLoaded: hasLoaded ?? this.hasLoaded,
    tournament: tournament ?? this.tournament,
    matches: matches ?? this.matches,
    courts: courts ?? this.courts,
    groups: groups ?? this.groups,
    umpires: umpires ?? this.umpires,
    ownAssignmentIds: ownAssignmentIds ?? this.ownAssignmentIds,
    filters: filters ?? this.filters,
    viewMode: viewMode ?? this.viewMode,
    visibleCount: visibleCount ?? this.visibleCount,
    showPlayerNames: showPlayerNames ?? this.showPlayerNames,
    busyMatchIds: busyMatchIds ?? this.busyMatchIds,
    busyCategoryIds: busyCategoryIds ?? this.busyCategoryIds,
    currentUserId: currentUserId ?? this.currentUserId,
    currentUserRole: currentUserRole ?? this.currentUserRole,
    error: identical(error, _unset) ? this.error : error,
    courtsError: identical(courtsError, _unset)
        ? this.courtsError
        : courtsError,
    groupsError: identical(groupsError, _unset)
        ? this.groupsError
        : groupsError,
    umpiresError: identical(umpiresError, _unset)
        ? this.umpiresError
        : umpiresError,
  );
}

const _unset = Object();

class TournamentScheduleController extends Notifier<TournamentScheduleState> {
  TournamentScheduleController(this.idOrSlug);

  final String idOrSlug;
  StreamSubscription<SocketEvent>? _eventSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Timer? _refreshDebounce;
  SocketClient? _socket;
  bool _connectedOnce = false;
  String? _joinedTournamentId;

  TournamentService get _service => ref.read(tournamentServiceProvider);

  @override
  TournamentScheduleState build() {
    final user = ref.watch(authControllerProvider).user;
    ref.onDispose(() {
      _refreshDebounce?.cancel();
      unawaited(_eventSubscription?.cancel());
      unawaited(_connectionSubscription?.cancel());
      if (_joinedTournamentId case final tournamentId?) {
        _socket?.leaveTournament(tournamentId);
      }
    });
    return TournamentScheduleState(
      currentUserId: user?.id,
      currentUserRole: user?.role,
    );
  }

  Future<void> load({bool force = false}) async {
    if (state.isLoading || (state.hasLoaded && !force)) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tournament = await _service.detail(idOrSlug);
      final user = ref.read(authControllerProvider).user;
      final canEdit =
          user?.role == UserRole.admin || user?.id == tournament.hostId;
      final canLoadAssignments =
          user != null &&
          user.role != UserRole.guest &&
          user.role != UserRole.player;

      var matches = const <TournamentMatch>[];
      var courts = const <TournamentCourt>[];
      var groups = const <TournamentCategoryGroup>[];
      var umpires = const <TournamentUmpire>[];
      var ownAssignments = const <TournamentMatch>[];
      Object? courtsError;
      Object? groupsError;
      Object? umpiresError;

      Future<void> loadCourts() async {
        try {
          courts = await _service.courts(tournament.id);
        } on Object catch (error) {
          courtsError = error;
        }
      }

      Future<void> loadGroups() async {
        try {
          groups = await _loadGroups(tournament.categories);
        } on Object catch (error) {
          groupsError = error;
        }
      }

      Future<void> loadUmpires() async {
        try {
          umpires = await _service.umpires(tournament.id);
        } on Object catch (error) {
          umpiresError = error;
        }
      }

      Future<void> loadAssignments() async {
        try {
          ownAssignments = await _service.ownAssignments(tournament.id);
        } on Object {
          ownAssignments = const [];
        }
      }

      await Future.wait<void>([
        Future<void>.sync(() async {
          matches = await _service.matches(tournament.id);
        }),
        loadCourts(),
        loadGroups(),
        if (canEdit) loadUmpires(),
        if (canLoadAssignments) loadAssignments(),
      ]);
      final showPlayerNames = await ref
          .read(tournamentSchedulePreferencesProvider)
          .readShowPlayerNames();
      state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        tournament: tournament,
        matches: matches,
        courts: courts,
        groups: groups,
        umpires: umpires,
        ownAssignmentIds: {for (final match in ownAssignments) match.id},
        showPlayerNames: showPlayerNames,
        currentUserId: user?.id,
        currentUserRole: user?.role,
        error: null,
        courtsError: courtsError,
        groupsError: groupsError,
        umpiresError: umpiresError,
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

  Future<List<TournamentCategoryGroup>> _loadGroups(
    List<TournamentCategory> categories,
  ) async => (await Future.wait([
    for (final category in categories) _service.categoryGroups(category.id),
  ])).expand((value) => value).toList(growable: false);

  void setFilters(TournamentScheduleFilters filters) {
    state = state.copyWith(filters: filters, visibleCount: 50);
  }

  void setViewMode(TournamentScheduleViewMode mode) {
    state = state.copyWith(viewMode: mode);
  }

  void setPageSize(int pageSize) {
    if (state.visibleCount < pageSize) {
      state = state.copyWith(visibleCount: pageSize);
    }
  }

  void loadMore([int amount = 50]) {
    state = state.copyWith(visibleCount: state.visibleCount + amount);
  }

  Future<void> setShowPlayerNames({required bool value}) async {
    if (value == state.showPlayerNames) return;
    state = state.copyWith(showPlayerNames: value);
    await ref
        .read(tournamentSchedulePreferencesProvider)
        .writeShowPlayerNames(value: value);
  }

  Future<void> togglePlayerNames() async {
    await setShowPlayerNames(value: !state.showPlayerNames);
  }

  void setRefereeOnly({required bool value}) {
    if (value == state.filters.refereeOnly) return;
    state = state.copyWith(
      filters: state.filters.copyWith(refereeOnly: value),
    );
  }

  void toggleRefereeOnly() {
    setRefereeOnly(value: !state.filters.refereeOnly);
  }

  Future<void> refresh() async {
    final tournament = state.tournament;
    if (tournament == null) return load(force: true);
    try {
      final matches = await _service.matches(tournament.id);
      state = state.copyWith(matches: matches, error: null);
    } on Object catch (error) {
      state = state.copyWith(error: error);
    }
  }

  Future<void> updateSchedule(TournamentScheduleUpdateDraft draft) async {
    if (state.isBusy(draft.matchId) || !state.canEdit) return;
    final previous = state.matches;
    final selectedCourt = state.courts
        .where((court) => court.id == draft.courtId)
        .firstOrNull;
    final selectedReferee = state.umpires
        .where((umpire) => umpire.id == draft.refereeId)
        .firstOrNull;
    state = state.copyWith(
      busyMatchIds: {...state.busyMatchIds, draft.matchId},
      matches: [
        for (final match in previous)
          if (match.id == draft.matchId)
            match.copyWith(
              matchCode: draft.matchCode,
              startTime: draft.startTime,
              clearStartTime: draft.startTime == null,
              estimatedEndTime: draft.endTime,
              clearEstimatedEndTime: draft.endTime == null,
              courtId: draft.courtId,
              court: selectedCourt,
              clearCourt: draft.courtId == null,
              refereeId: draft.refereeId,
              referee: selectedReferee,
              clearReferee: draft.refereeId == null,
            )
          else
            match,
      ],
    );
    try {
      await Future.wait([
        _service.updateMatchCode(draft.matchId, draft.matchCode),
        _service.updateMatchSchedule(draft),
        if (draft.refereeId != null)
          _service.assignReferee(draft.matchId, draft.refereeId!)
        else if (previous
                .where((match) => match.id == draft.matchId)
                .firstOrNull
                ?.refereeId !=
            null)
          _service.unassignReferee(draft.matchId),
      ]);
    } on Object {
      state = state.copyWith(matches: previous);
      unawaited(refresh());
      rethrow;
    } finally {
      state = state.copyWith(
        busyMatchIds: {...state.busyMatchIds}..remove(draft.matchId),
      );
    }
  }

  Future<void> saveResult(String matchId, TournamentResultDraft draft) =>
      _runMatchMutation(matchId, () => _service.saveResult(matchId, draft));

  Future<void> resetResult(String matchId) =>
      _runMatchMutation(matchId, () => _service.resetResult(matchId));

  Future<void> deleteMatch(String matchId) async {
    if (state.isBusy(matchId) || !state.canEdit) return;
    state = state.copyWith(busyMatchIds: {...state.busyMatchIds, matchId});
    try {
      await _service.deleteMatch(matchId);
      state = state.copyWith(
        matches: state.matches
            .where((match) => match.id != matchId)
            .toList(growable: false),
      );
      await refresh();
    } finally {
      state = state.copyWith(
        busyMatchIds: {...state.busyMatchIds}..remove(matchId),
      );
    }
  }

  Future<void> _runMatchMutation(
    String matchId,
    Future<TournamentMatch> Function() operation,
  ) async {
    if (state.isBusy(matchId) || !state.canEdit) return;
    state = state.copyWith(busyMatchIds: {...state.busyMatchIds, matchId});
    try {
      final updated = await operation();
      state = state.copyWith(
        matches: [
          for (final match in state.matches)
            if (match.id == matchId) updated else match,
        ],
      );
      await refresh();
    } finally {
      state = state.copyWith(
        busyMatchIds: {...state.busyMatchIds}..remove(matchId),
      );
    }
  }

  Future<void> completeGroupStage(String categoryId) async {
    if (state.busyCategoryIds.contains(categoryId) || !state.canEdit) return;
    state = state.copyWith(
      busyCategoryIds: {...state.busyCategoryIds, categoryId},
    );
    try {
      await _service.completeGroupStage(categoryId);
      await refresh();
    } finally {
      state = state.copyWith(
        busyCategoryIds: {...state.busyCategoryIds}..remove(categoryId),
      );
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
        .listen(_handleRealtimeEvent);
    _connectionSubscription = socket.connectionState.listen((connected) {
      if (connected && _connectedOnce) unawaited(refresh());
      if (connected) _connectedOnce = true;
    });
  }

  void _handleRealtimeEvent(SocketEvent event) {
    if (event.name == TournamentEvent.ended) {
      unawaited(refresh());
      if (state.tournament case final tournament?) {
        _socket?.leaveTournament(tournament.id);
      }
      return;
    }
    if (event.name == TournamentEvent.scheduleUpdated ||
        event.name == TournamentEvent.refereeAssigned) {
      _scheduleRefresh();
      return;
    }
    final payload = event.data['match'];
    if (payload is! Map) return;
    final incoming = Map<String, dynamic>.from(payload);
    final matchId = incoming['matchId']?.toString();
    if (matchId == null || !state.matches.any((match) => match.id == matchId)) {
      _scheduleRefresh();
      return;
    }
    state = state.copyWith(
      matches: [
        for (final match in state.matches)
          if (match.id == matchId)
            mergeTournamentRealtimeMatch(match, incoming)
          else
            match,
      ],
    );
    if (event.name == TournamentEvent.matchEnded) _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(refresh()),
    );
  }
}

final NotifierProviderFamily<
  TournamentScheduleController,
  TournamentScheduleState,
  String
>
tournamentScheduleControllerProvider =
    NotifierProvider.family<
      TournamentScheduleController,
      TournamentScheduleState,
      String
    >(TournamentScheduleController.new);
