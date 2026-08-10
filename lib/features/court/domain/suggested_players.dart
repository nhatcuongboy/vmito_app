import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/shared/models/session_player.dart';

part 'suggested_players.freezed.dart';
part 'suggested_players.g.dart';

/// One side of a suggested match.
@freezed
abstract class SuggestedPair with _$SuggestedPair {
  const factory SuggestedPair({
    @Default(<SessionPlayer>[]) List<SessionPlayer> players,
    @Default(0) int totalLevelScore,
  }) = _SuggestedPair;

  factory SuggestedPair.fromJson(Map<String, dynamic> json) =>
      _$SuggestedPairFromJson(json);
}

/// What `GET /courts/:id/suggested-players` returns.
///
/// **The app renders this; it never computes it.** Matchmaking is server-side
/// (CLAUDE.md non-negotiable #4) — the backend weighs level balance, wait time
/// and, when `useAi=true`, an LLM pass whose rationale arrives in [aiReason].
@freezed
abstract class SuggestedPlayers with _$SuggestedPlayers {
  const factory SuggestedPlayers({
    required SuggestedPair pair1,
    required SuggestedPair pair2,
    @Default(0) int scoreDifference,
    @Default(0) int totalPlayersConsidered,
    @Default(false) bool usedAi,

    /// Free prose from the model, in the language asked for. Present only when
    /// the AI pass actually ran and succeeded — the backend silently falls back
    /// to the deterministic algorithm on failure, leaving this null.
    String? aiReason,
  }) = _SuggestedPlayers;

  factory SuggestedPlayers.fromJson(Map<String, dynamic> json) =>
      _$SuggestedPlayersFromJson(json);

  const SuggestedPlayers._();

  /// Every suggested player, pair 1 first.
  List<SessionPlayer> get allPlayers => [...pair1.players, ...pair2.players];
}
