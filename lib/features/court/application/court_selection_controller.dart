// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/locale_controller.dart';
import 'package:vmito_app/features/court/application/court_selection_state.dart';
import 'package:vmito_app/features/court/data/repositories/court_repository_impl.dart';
import 'package:vmito_app/features/court/domain/court_seating.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Identifies one open assign sheet.
///
/// A record, so the family key has structural equality: reopening the same
/// sheet reuses its provider, and the pre-select variant is a separate one even
/// on the same court.
typedef CourtSelectionKey = ({
  String sessionId,
  String courtId,
  bool preSelect,
});

/// Drives the assign sheet.
///
/// Riverpod 3 disposes a provider once nothing watches it, which is what this
/// relies on: closing the sheet must forget a half-built line-up, or reopening
/// it would resume someone else's abandoned pick.
class CourtSelectionController extends Notifier<CourtSelectionState> {
  CourtSelectionController(this.key);

  final CourtSelectionKey key;

  /// Bumped on every fetch so a slow response from an earlier configuration
  /// can be recognised and dropped.
  int _requestId = 0;

  @override
  CourtSelectionState build() {
    final session = _session;
    final court = _court(session);
    // An empty court has no occupancy to infer from, so fall back to what the
    // host configured for the session.
    final matchType =
        court?.matchTypeOr(session?.defaultMatchType ?? MatchType.doubles) ??
        MatchType.doubles;
    return CourtSelectionState(
      matchType: matchType,
      slots: List<String?>.filled(matchType.playerCount, null),
    );
  }

  Session? get _session =>
      ref.read(sessionDetailProvider(key.sessionId)).asData?.value;

  Court? _court(Session? session) {
    for (final court in session?.courts ?? const <Court>[]) {
      if (court.id == key.courtId) return court;
    }
    return null;
  }

  /// Players the host can still put on a court, longest wait first.
  List<SessionPlayer> get waitingPlayers => _session?.waitingQueue ?? const [];

  /// [waitingPlayers] narrowed by the search box.
  ///
  /// Matches name **and** shirt number — a host calling "số 7" should not have
  /// to remember that player's name.
  List<SessionPlayer> get visiblePlayers {
    final query = state.search.trim().toLowerCase();
    if (query.isEmpty) return waitingPlayers;
    return [
      for (final player in waitingPlayers)
        if ((player.name?.toLowerCase().contains(query) ?? false) ||
            '${player.playerNumber}'.contains(query))
          player,
    ];
  }

  SessionPlayer? playerById(String? id) {
    if (id == null) return null;
    for (final player in waitingPlayers) {
      if (player.id == id) return player;
    }
    return null;
  }

  /// Seat index → player, for the selection court.
  List<SessionPlayer?> get seatedPlayers => [
    for (final id in state.slots) playerById(id),
  ];

  // --- Manual picking -------------------------------------------------------

  /// Switches singles ↔ doubles.
  ///
  /// Clears the picks: a doubles line-up has no meaningful first two players,
  /// and silently keeping some of them would let the host confirm a pairing
  /// they never chose.
  void setMatchType(MatchType matchType) {
    if (matchType == state.matchType) return;
    state = state.copyWith(
      matchType: matchType,
      slots: List<String?>.filled(matchType.playerCount, null),
      activeSlot: 0,
      suggestion: null,
      suggestionError: null,
    );
    if (state.mode == CourtSelectionMode.auto) unawaitedRefreshSuggestion();
  }

  /// Adds a player to the active seat, or removes them if already picked.
  void togglePlayer(String playerId) {
    final existing = state.slots.indexOf(playerId);
    if (existing != -1) {
      clearSlot(existing);
      return;
    }
    final slots = [...state.slots];
    final target = state.activeSlot.clamp(0, slots.length - 1);
    slots[target] = playerId;
    state = state.copyWith(
      slots: slots,
      activeSlot: CourtSeating.nextEmptySeat(slots, target),
    );
  }

  /// Empties a seat and parks the cursor there, so a mis-tap is one tap to fix.
  void clearSlot(int seat) {
    if (seat < 0 || seat >= state.slots.length) return;
    final slots = [...state.slots]..[seat] = null;
    state = state.copyWith(slots: slots, activeSlot: seat);
  }

  /// Taps on the court: an empty seat becomes active, a filled one empties.
  void selectSlot(int seat) {
    if (seat < 0 || seat >= state.slots.length) return;
    if (state.slots[seat] != null) {
      clearSlot(seat);
      return;
    }
    state = state.copyWith(activeSlot: seat);
  }

  void setSearch(String search) => state = state.copyWith(search: search);

  // --- Server matchmaking ---------------------------------------------------

  void setMode(CourtSelectionMode mode) {
    if (mode == state.mode) return;
    state = state.copyWith(mode: mode);
    if (mode == CourtSelectionMode.auto && state.suggestion == null) {
      unawaitedRefreshSuggestion();
    }
  }

  void setUseAi({required bool useAi}) {
    if (useAi == state.useAi) return;
    state = state.copyWith(useAi: useAi);
    unawaitedRefreshSuggestion();
  }

  /// Fire-and-forget wrapper, for call sites that are not themselves async.
  ///
  /// The future is dropped on purpose: the sheet reads progress and failure
  /// off `state`, so there is nothing for a caller to await.
  void unawaitedRefreshSuggestion() {
    refreshSuggestion().ignore();
  }

  /// Asks the server who should play next.
  ///
  /// Matchmaking is server-side — the app renders the answer and never
  /// computes it (CLAUDE.md non-negotiable #4).
  Future<void> refreshSuggestion() async {
    final requestId = ++_requestId;
    state = state.copyWith(isLoadingSuggestion: true, suggestionError: null);

    try {
      final suggestion = await ref
          .read(courtRepositoryProvider)
          .suggestedPlayers(
            key.courtId,
            useAi: state.useAi,
            language: ref.read(localeControllerProvider).languageCode,
            matchType: state.matchType,
          );
      // A slower earlier request must not overwrite a newer answer — the host
      // can flip the AI toggle faster than the LLM responds.
      if (requestId != _requestId) return;
      state = state.copyWith(
        suggestion: suggestion,
        isLoadingSuggestion: false,
      );
    } on Object catch (error) {
      if (requestId != _requestId) return;
      state = state.copyWith(
        suggestionError: error,
        isLoadingSuggestion: false,
        suggestion: null,
      );
    }
  }

  // --- Confirming -----------------------------------------------------------

  /// The seats to send, or null when the sheet is not ready to confirm.
  List<PlayerPosition>? confirmationPayload() {
    if (!state.isComplete) return null;
    if (state.mode == CourtSelectionMode.manual) return state.manualPayload;

    final suggestion = state.suggestion;
    if (suggestion == null) return null;
    return _seatPairs(suggestion.pair1.players, suggestion.pair2.players);
  }

  /// Lays the server's two pairs onto the court's seats.
  List<PlayerPosition> _seatPairs(
    List<SessionPlayer> pair1,
    List<SessionPlayer> pair2,
  ) => CourtSeating.seatPairs(
    pair1,
    pair2,
    matchType: state.matchType,
    direction: _court(_session)?.direction ?? CourtDirection.horizontal,
  );
}

final courtSelectionControllerProvider =
    NotifierProvider.family<
      CourtSelectionController,
      CourtSelectionState,
      CourtSelectionKey
    >(CourtSelectionController.new);
