/// How evenly matched the two sides of a proposed match are.
///
/// Ported from `manualPairStats` in
/// `vmito-fe/src/components/session/CourtPlayerSelectionModal.tsx`.
///
/// **This is display arithmetic, not matchmaking.** Who *should* play next is
/// decided by `GET /courts/:id/suggested-players` on the server. This only
/// scores a line-up the host is already looking at, so they can see the gap.
library;

import 'package:vmito_domain/src/court/court_pairs.dart';
import 'package:vmito_domain/src/reference/player_level.dart';

/// The two sides scored, and the gap between them.
class PairBalance {
  const PairBalance({required this.pair1Score, required this.pair2Score});

  final int pair1Score;
  final int pair2Score;

  int get scoreDifference => (pair1Score - pair2Score).abs();
}

/// Scores the seats the host has filled so far, or null when a side is empty.
///
/// [seats] is indexed by court slot and may contain gaps — the host fills slots
/// in any order. **Slots 0 and 1 are one side, 2 and 3 the other, regardless of
/// direction:** the selection court always draws pair 1 on the left. That is
/// not the same split `groupPairs` uses for teams on a real court, and the two
/// must not be merged.
///
/// An unknown level scores as intermediate rather than zero, so an unrated
/// player does not drag their side down.
PairBalance? pairBalance(List<int?> seats, CourtFormat format) {
  if (format == CourtFormat.singles) {
    if (seats.length < 2) return null;
    final first = seats[0];
    final second = seats[1];
    // Singles needs both players before a comparison means anything; the web
    // returns null here rather than scoring one side against zero.
    if (first == null || second == null) return null;
    return PairBalance(
      pair1Score: _levelScore(first),
      pair2Score: _levelScore(second),
    );
  }

  final filled = [
    for (var slot = 0; slot < 4; slot++)
      slot < seats.length ? seats[slot] : null,
  ];
  final pair1 = [filled[0], filled[1]].nonNulls;
  final pair2 = [filled[2], filled[3]].nonNulls;
  // Doubles scores partial sides — a host mid-selection still wants the gap.
  if (pair1.isEmpty || pair2.isEmpty) return null;

  return PairBalance(
    pair1Score: pair1.fold(0, (sum, level) => sum + _levelScore(level)),
    pair2Score: pair2.fold(0, (sum, level) => sum + _levelScore(level)),
  );
}

/// A level's display rank, falling back to intermediate for anything unknown.
int _levelScore(int level) => levelRank(level) ?? _intermediateRank;

/// `TB`. Rank, not id — the ids are not in display order.
final int _intermediateRank = levelRank(_intermediateLevelId) ?? 3;

/// `PlayerLevel.INTERMEDIATE` on the wire.
const int _intermediateLevelId = 4;
