import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/court/domain/suggested_players.dart';
import 'package:vmito_app/shared/models/match.dart';

part 'court_selection_state.freezed.dart';

/// Which half of the assign sheet the host is using.
enum CourtSelectionMode {
  /// Pick the players and their seats by hand.
  manual,

  /// Ask the server who should play next.
  auto,
}

/// Everything the assign sheet holds while it is open.
///
/// Ports `useCourtsTabModals.ts` (324 lines on web). It lives in a Notifier
/// rather than the sheet's `State` because it carries a cancellable fetch with
/// a stale-response guard, which is not testable without pumping widgets.
@freezed
abstract class CourtSelectionState with _$CourtSelectionState {
  const factory CourtSelectionState({
    @Default(MatchType.doubles) MatchType matchType,
    @Default(CourtSelectionMode.manual) CourtSelectionMode mode,

    /// Whether the server should run its LLM pass. Costs money, so it is off
    /// until the host asks.
    @Default(false) bool useAi,

    /// Seat index → player id. Length follows [matchType]; nulls are gaps.
    @Default(<String?>[null, null, null, null]) List<String?> slots,

    /// The seat the next pick lands in.
    @Default(0) int activeSlot,
    @Default('') String search,

    /// Null before the host has opened the auto tab.
    SuggestedPlayers? suggestion,
    @Default(false) bool isLoadingSuggestion,

    /// Set when the last suggestion fetch failed. Cleared on the next attempt.
    Object? suggestionError,
  }) = _CourtSelectionState;

  const CourtSelectionState._();

  /// Player ids in seat order, gaps dropped.
  List<String> get selectedIds => [for (final id in slots) ?id];

  int get requiredCount => matchType.playerCount;

  /// Whether the host can confirm. Manual needs every seat filled; auto needs
  /// a suggestion that came back.
  bool get isComplete => mode == CourtSelectionMode.auto
      ? suggestion != null && !isLoadingSuggestion
      : selectedIds.length == requiredCount;

  /// The payload for select-players / pre-select, in seat order.
  ///
  /// Auto mode lays the server's two pairs onto the court itself — see
  /// `CourtSelectionController.confirmationPayload`, which owns that mapping
  /// because it needs the court's direction.
  List<PlayerPosition> get manualPayload => [
    for (var seat = 0; seat < slots.length; seat++)
      if (slots[seat] case final id?)
        PlayerPosition(playerId: id, position: seat),
  ];
}
