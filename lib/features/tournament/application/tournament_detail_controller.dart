import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_podium.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

final FutureProviderFamily<String, String> tournamentTitleProvider =
    FutureProvider.family<String, String>((ref, idOrSlug) async {
      final tournament = await ref
          .watch(tournamentServiceProvider)
          .detail(idOrSlug);
      return tournament.name;
    });

class TournamentDetailState {
  const TournamentDetailState({
    required this.tournament,
    this.matches = const [],
    this.sponsors = const [],
    this.standingsByCategory = const {},
    this.matchesError,
    this.sponsorsError,
    this.standingsError,
    this.statusOverride,
  });

  final TournamentDetail tournament;
  final List<TournamentMatch> matches;
  final List<TournamentSponsor> sponsors;
  final Map<String, List<TournamentStandingGroup>> standingsByCategory;
  final Object? matchesError;
  final Object? sponsorsError;
  final Object? standingsError;
  final TournamentStatus? statusOverride;

  TournamentStatus get effectiveStatus => statusOverride ?? tournament.status;

  List<TournamentCategoryPodium> get podiums => [
    for (final category in tournament.categories)
      computeTournamentPodium(
        category: category,
        matches: matches,
        standings: standingsByCategory[category.id] ?? const [],
      ),
  ];

  TournamentDetailState copyWith({
    List<TournamentMatch>? matches,
    List<TournamentSponsor>? sponsors,
    Map<String, List<TournamentStandingGroup>>? standingsByCategory,
    Object? matchesError = _unset,
    Object? sponsorsError = _unset,
    Object? standingsError = _unset,
    TournamentStatus? statusOverride,
  }) => TournamentDetailState(
    tournament: tournament,
    matches: matches ?? this.matches,
    sponsors: sponsors ?? this.sponsors,
    standingsByCategory: standingsByCategory ?? this.standingsByCategory,
    matchesError: identical(matchesError, _unset)
        ? this.matchesError
        : matchesError,
    sponsorsError: identical(sponsorsError, _unset)
        ? this.sponsorsError
        : sponsorsError,
    standingsError: identical(standingsError, _unset)
        ? this.standingsError
        : standingsError,
    statusOverride: statusOverride ?? this.statusOverride,
  );
}

const _unset = Object();

class TournamentDetailController extends AsyncNotifier<TournamentDetailState> {
  TournamentDetailController(this.idOrSlug);

  final String idOrSlug;
  Timer? _refreshDebounce;
  StreamSubscription<SocketEvent>? _eventSubscription;
  SocketClient? _socket;
  String? _tournamentId;

  @override
  Future<TournamentDetailState> build() async {
    ref.onDispose(() {
      _refreshDebounce?.cancel();
      unawaited(_eventSubscription?.cancel());
      if (_tournamentId case final tournamentId?) {
        _socket?.leaveTournament(tournamentId);
      }
      _socket?.dispose();
    });
    final tournament = await ref
        .read(tournamentServiceProvider)
        .detail(idOrSlug);
    _tournamentId = tournament.id;
    final loaded = await _loadSections(tournament);
    if (loaded.effectiveStatus == TournamentStatus.preparing ||
        loaded.effectiveStatus == TournamentStatus.inProgress) {
      _startRealtime(
        loaded.tournament.id,
        ref.read(tokenStorageProvider),
      );
    }
    return loaded;
  }

  Future<TournamentDetailState> _loadSections(
    TournamentDetail tournament,
  ) async {
    final service = ref.read(tournamentServiceProvider);
    var matches = const <TournamentMatch>[];
    var sponsors = const <TournamentSponsor>[];
    var standings = const <String, List<TournamentStandingGroup>>{};
    Object? matchesError;
    Object? sponsorsError;
    Object? standingsError;

    await Future.wait([
      Future.sync(
        () => service.matches(tournament.id),
      ).then((value) => matches = value).catchError((Object error) {
        matchesError = error;
        return <TournamentMatch>[];
      }),
      Future.sync(
        () => service.sponsors(tournament.id),
      ).then((value) => sponsors = value).catchError((Object error) {
        sponsorsError = error;
        return <TournamentSponsor>[];
      }),
      Future.sync(
        () => _loadStandings(tournament.categories),
      ).then((value) => standings = value).catchError((Object error) {
        standingsError = error;
        return <String, List<TournamentStandingGroup>>{};
      }),
    ]);
    return TournamentDetailState(
      tournament: tournament,
      matches: matches,
      sponsors: sponsors,
      standingsByCategory: standings,
      matchesError: matchesError,
      sponsorsError: sponsorsError,
      standingsError: standingsError,
    );
  }

  Future<Map<String, List<TournamentStandingGroup>>> _loadStandings(
    List<TournamentCategory> categories,
  ) async {
    final service = ref.read(tournamentServiceProvider);
    final entries = await Future.wait([
      for (final category in categories)
        service
            .standings(category.id)
            .then((value) => MapEntry(category.id, value)),
    ]);
    return Map.fromEntries(entries);
  }

  void _startRealtime(String tournamentId, TokenStorage tokenStorage) {
    final socket = SocketClient(
      tokenStorage: tokenStorage,
      namespace: SocketNamespace.tournaments,
      observedEvents: TournamentEvent.all,
    );
    _socket = socket..connect();
    socket.joinTournament(tournamentId);
    _eventSubscription = socket.events
        .where((event) => event.data['tournamentId'] == tournamentId)
        .listen((event) {
          if (event.name == TournamentEvent.ended) {
            final wireStatus = event.data['status'] as String?;
            if (wireStatus == 'FINISHED' || wireStatus == 'CANCELLED') {
              final current = state.value;
              if (current != null) {
                state = AsyncData(
                  current.copyWith(
                    statusOverride: TournamentStatus.fromWire(wireStatus),
                  ),
                );
              }
            }
            socket.leaveTournament(tournamentId);
            _scheduleRealtimeRefresh(refreshStandings: true);
            socket.dispose();
            _socket = null;
            return;
          }
          _scheduleRealtimeRefresh(
            refreshStandings: event.name == TournamentEvent.matchEnded,
          );
        });
  }

  void _scheduleRealtimeRefresh({required bool refreshStandings}) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(refreshLiveSections(refreshStandings: refreshStandings));
    });
  }

  Future<void> refresh() async {
    final previous = state.value;
    try {
      final tournament = await ref
          .read(tournamentServiceProvider)
          .detail(idOrSlug);
      state = AsyncData(await _loadSections(tournament));
    } on Object catch (error, stackTrace) {
      if (previous == null) state = AsyncError(error, stackTrace);
    }
  }

  Future<void> refreshLiveSections({bool refreshStandings = true}) async {
    final current = state.value;
    if (current == null) return;
    final service = ref.read(tournamentServiceProvider);
    try {
      final matches = await service.matches(current.tournament.id);
      var standings = current.standingsByCategory;
      if (refreshStandings) {
        standings = await _loadStandings(current.tournament.categories);
      }
      state = AsyncData(
        current.copyWith(
          matches: matches,
          standingsByCategory: standings,
          matchesError: null,
          standingsError: refreshStandings ? null : current.standingsError,
        ),
      );
    } on Object catch (error) {
      state = AsyncData(current.copyWith(matchesError: error));
    }
  }
}

// Provider-family declarations are clearer with their inferred Riverpod type.
// ignore: specify_nonobvious_property_types
final tournamentDetailControllerProvider =
    AsyncNotifierProvider.family<
      TournamentDetailController,
      TournamentDetailState,
      String
    >(TournamentDetailController.new);
