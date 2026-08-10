import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_result_draft.freezed.dart';

/// One player's score line, as `EndMatchDto.score` expects it.
@freezed
abstract class PlayerScore with _$PlayerScore {
  const factory PlayerScore({required String playerId, required int score}) =
      _PlayerScore;
}

/// What the host is about to submit when ending a match.
///
/// No `fromJson` on purpose — this is outbound only. It also has no
/// `toJson`: every field on `EndMatchDto` is optional, and the backend
/// distinguishes "not sent" from "sent empty", so [toRequestBody] omits unset
/// fields rather than serialising nulls.
@freezed
abstract class MatchResultDraft with _$MatchResultDraft {
  const factory MatchResultDraft({
    /// Per-player, not per-team. The web expands each pair's single score
    /// across that pair's players — see [MatchResultDraft.fromPairs].
    @Default(<PlayerScore>[]) List<PlayerScore> score,
    @Default(<String>[]) List<String> winnerIds,
    @Default(false) bool isDraw,
    String? notes,

    /// Shuttlecocks used. Fractional on purpose — the column is a `Float` and
    /// hosts really do log `2.5`.
    double? shuttlecockCount,
  }) = _MatchResultDraft;

  /// Builds a draft from the two sides of the court.
  ///
  /// A side with no score entered contributes no score lines at all, which is
  /// how a host records only a winner. [winningPair] is 1, 2, or null.
  factory MatchResultDraft.fromPairs({
    required List<String> pair1PlayerIds,
    required List<String> pair2PlayerIds,
    int? pair1Score,
    int? pair2Score,
    int? winningPair,
    bool isDraw = false,
    String? notes,
    double? shuttlecockCount,
  }) {
    final lines = <PlayerScore>[
      if (pair1Score != null)
        for (final id in pair1PlayerIds)
          PlayerScore(playerId: id, score: pair1Score),
      if (pair2Score != null)
        for (final id in pair2PlayerIds)
          PlayerScore(playerId: id, score: pair2Score),
    ];
    return MatchResultDraft(
      score: lines,
      winnerIds: isDraw || winningPair == null
          ? const <String>[]
          : (winningPair == 1 ? pair1PlayerIds : pair2PlayerIds),
      isDraw: isDraw,
      notes: notes,
      shuttlecockCount: shuttlecockCount,
    );
  }

  const MatchResultDraft._();

  /// The request body, with unset fields left out entirely.
  Map<String, dynamic> toRequestBody() {
    final trimmedNotes = notes?.trim();
    return <String, dynamic>{
      if (score.isNotEmpty)
        'score': [
          for (final line in score)
            {'playerId': line.playerId, 'score': line.score},
        ],
      if (winnerIds.isNotEmpty) 'winnerIds': winnerIds,
      if (isDraw) 'isDraw': true,
      if (trimmedNotes != null && trimmedNotes.isNotEmpty) 'notes': trimmedNotes,
      if (shuttlecockCount != null) 'shuttlecockCount': shuttlecockCount,
    };
  }
}
