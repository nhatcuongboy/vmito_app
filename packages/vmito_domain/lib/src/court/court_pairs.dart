/// How a court's four seats map to teams and to screen coordinates.
///
/// Ported from `vmito-fe/src/utils/match-repeat-warning.ts` (`getPairGroups`)
/// and the slot mapping in `src/components/court/BadmintonCourt.tsx`.
///
/// **The two mappings are different and both matter.** Direction changes which
/// seats are teammates *and* where a seat is drawn, but not in the same way:
///
/// ```text
///                 teams                     draw order
/// HORIZONTAL   [0,1] vs [2,3]            visual slots 0,2,1,3
/// VERTICAL     [0,2] vs [1,3]            visual slots 0,1,2,3
/// ```
library;

/// Which way a court is laid out. Mirrors `CourtDirection` on the wire.
enum PairDirection { horizontal, vertical }

/// Singles or doubles.
enum CourtFormat {
  singles,
  doubles;

  /// 2 for singles, 4 for doubles.
  int get playerCount => this == CourtFormat.singles ? 2 : 4;
}

/// A player occupying a numbered seat.
///
/// [position] is already resolved by the caller — the web reads it from
/// `courtPosition`, then `position`, then the array index, and which of those
/// applies depends on whether a match is running. Resolving it outside keeps
/// this package free of wire types.
class PositionedPlayer {
  const PositionedPlayer({
    required this.id,
    required this.position,
    this.name,
    this.playerNumber,
  });

  final String id;
  final int position;
  final String? name;
  final int? playerNumber;
}

/// The two sides of a match.
class CourtPairs {
  const CourtPairs({
    required this.pair1,
    required this.pair2,
    required this.format,
  });

  final List<PositionedPlayer> pair1;
  final List<PositionedPlayer> pair2;
  final CourtFormat format;
}

/// Seat order for drawing, given a direction.
///
/// The API numbers seats by team; the court draws them by geometry. For
/// `HORIZONTAL` those disagree, which is why seat 1 renders third.
List<int> visualSlotOrder(PairDirection direction) =>
    direction == PairDirection.vertical
    ? const [0, 1, 2, 3]
    : const [0, 2, 1, 3];

/// Splits [players] into two sides, or null when the court is not full.
///
/// [format] is inferred from the head count when omitted — that is what the
/// web does for historical matches, where nothing records which it was.
/// Returning null rather than a half-filled pair is deliberate: an incomplete
/// court has no teams yet, and guessing would produce phantom warnings.
CourtPairs? groupPairs(
  Iterable<PositionedPlayer> players,
  PairDirection direction, [
  CourtFormat? format,
]) {
  final positioned = [...players]
    ..sort((a, b) => a.position.compareTo(b.position));

  final effective =
      format ??
      (positioned.length <= 2 ? CourtFormat.singles : CourtFormat.doubles);
  if (positioned.length < effective.playerCount) return null;

  if (effective == CourtFormat.singles) {
    return CourtPairs(
      pair1: [positioned[0]],
      pair2: [positioned[1]],
      format: CourtFormat.singles,
    );
  }

  final bySeat = {for (final player in positioned) player.position: player};
  final pair1Seats = direction == PairDirection.vertical
      ? const [0, 2]
      : const [0, 1];
  final pair2Seats = direction == PairDirection.vertical
      ? const [1, 3]
      : const [2, 3];

  final pair1 = [for (final seat in pair1Seats) ?bySeat[seat]];
  final pair2 = [for (final seat in pair2Seats) ?bySeat[seat]];
  // Four players can still fail this: two of them may share a seat number, or
  // sit outside 0-3. Better no pairing than a wrong one.
  if (pair1.length < 2 || pair2.length < 2) return null;

  return CourtPairs(pair1: pair1, pair2: pair2, format: CourtFormat.doubles);
}
