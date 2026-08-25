import 'dart:convert';

/// The editable fields accepted by `PATCH /matches/:id`.
///
/// [playerIds] preserves court-position order. The pair lists are kept
/// separately because a vertical court groups positions 0+2 and 1+3.
class MatchUpdateDraft {
  const MatchUpdateDraft({
    required this.playerIds,
    required this.pair1PlayerIds,
    required this.pair2PlayerIds,
    required this.noResult,
    required this.pair1Score,
    required this.pair2Score,
    required this.isExtra,
    required this.notes,
    this.shuttlecockCount,
  });

  final List<String> playerIds;
  final List<String> pair1PlayerIds;
  final List<String> pair2PlayerIds;
  final bool noResult;
  final int pair1Score;
  final int pair2Score;
  final bool isExtra;
  final String notes;
  final double? shuttlecockCount;

  bool get isDraw => !noResult && pair1Score == pair2Score;

  List<String> get winnerIds {
    if (noResult || isDraw) return const [];
    return pair1Score > pair2Score ? pair1PlayerIds : pair2PlayerIds;
  }

  Map<String, dynamic> toRequestBody() => <String, dynamic>{
    // Web edits use the compact pair object. Sending an explicit null is
    // important: omitting score would leave the previous result untouched.
    'score': noResult
        ? null
        : jsonEncode({'pair1': pair1Score, 'pair2': pair2Score}),
    'winnerIds': winnerIds,
    'isDraw': isDraw,
    'isExtra': isExtra,
    'notes': notes.trim(),
    'playerIds': playerIds,
    if (shuttlecockCount != null) 'shuttlecockCount': shuttlecockCount,
  };
}
