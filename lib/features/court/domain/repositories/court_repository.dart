import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/court/domain/suggested_players.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/pre_selected_slot.dart';

/// The `Court` resource's data boundary — the port of
/// `vmito-fe/src/lib/api/court.service.ts`.
///
/// Courts live on their own backend controller with their own ten endpoints,
/// so they get their own repository rather than swelling `SessionRepository`.
abstract interface class CourtRepository {
  Future<Court> byId(String courtId);

  /// Seats players on a court, moving it to READY.
  ///
  /// Sends both `playerIds` and `players` because `SelectPlayersDto` accepts
  /// either and the web sends both; the position-bearing list is what actually
  /// determines who stands where.
  Future<void> selectPlayers(String courtId, List<PlayerPosition> players);

  Future<void> deselectPlayers(String courtId);

  Future<void> startMatch(String courtId);

  Future<void> endMatch(String courtId, MatchResultDraft result);

  Future<Match?> currentMatch(String courtId);

  /// Books the *next* match's line-up while the current one is still running.
  Future<void> preSelect(String courtId, List<PlayerPosition> players);

  Future<void> cancelPreSelect(String courtId);

  Future<List<PreSelectedSlot>> preSelection(String courtId);

  /// Server-side matchmaking. The app renders this and never computes it
  /// locally — CLAUDE.md non-negotiable #4.
  ///
  /// [language] shapes [SuggestedPlayers.aiReason]; pass the current locale
  /// rather than assuming Vietnamese.
  Future<SuggestedPlayers> suggestedPlayers(
    String courtId, {
    int? topCount,
    bool useAi = false,
    String? language,
    MatchType? matchType,
  });
}
