import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Where players go on a court, as seat numbers.
///
/// Pure functions, so the rules stay testable without a controller and cannot
/// quietly diverge between the assign sheet and its preview.
abstract final class CourtSeating {
  /// Lays two chosen pairs onto court seats.
  ///
  /// Teams must end up in the same column, and which seat numbers that means
  /// depends on the court's direction: horizontal seats a pair at 0+1,
  /// vertical at 0+2. Ports `useCourtsTabActions.ts`.
  static List<PlayerPosition> seatPairs(
    List<SessionPlayer> pair1,
    List<SessionPlayer> pair2, {
    required MatchType matchType,
    required CourtDirection direction,
  }) {
    if (matchType == MatchType.singles) {
      return [
        if (pair1.isNotEmpty)
          PlayerPosition(playerId: pair1.first.id, position: 0),
        if (pair2.isNotEmpty)
          PlayerPosition(playerId: pair2.first.id, position: 1),
      ];
    }

    final (pair1Seats, pair2Seats) = seatsForPairs(direction);
    return [
      for (var i = 0; i < pair1.length && i < 2; i++)
        PlayerPosition(playerId: pair1[i].id, position: pair1Seats[i]),
      for (var i = 0; i < pair2.length && i < 2; i++)
        PlayerPosition(playerId: pair2[i].id, position: pair2Seats[i]),
    ];
  }

  /// The seat numbers each side occupies, for doubles.
  static (List<int>, List<int>) seatsForPairs(CourtDirection direction) =>
      direction == CourtDirection.vertical
      ? (const [0, 2], const [1, 3])
      : (const [0, 1], const [2, 3]);

  /// Seat index → player, for previewing a pairing before it is sent.
  ///
  /// Uses the same mapping as [seatPairs] so the preview cannot show one
  /// arrangement and submit another.
  static List<SessionPlayer?> seatedPreview(
    List<SessionPlayer> pair1,
    List<SessionPlayer> pair2, {
    required MatchType matchType,
    required CourtDirection direction,
  }) {
    if (matchType == MatchType.singles) {
      return [
        if (pair1.isNotEmpty) pair1.first else null,
        if (pair2.isNotEmpty) pair2.first else null,
      ];
    }

    final seats = List<SessionPlayer?>.filled(4, null);
    final (pair1Seats, pair2Seats) = seatsForPairs(direction);
    for (var i = 0; i < pair1.length && i < 2; i++) {
      seats[pair1Seats[i]] = pair1[i];
    }
    for (var i = 0; i < pair2.length && i < 2; i++) {
      seats[pair2Seats[i]] = pair2[i];
    }
    return seats;
  }

  /// The next empty seat after [from], wrapping.
  ///
  /// Returns [from] when the court is full, so the cursor stays somewhere the
  /// host can act on rather than jumping to a seat they just filled.
  static int nextEmptySeat(List<String?> slots, int from) {
    for (var step = 1; step <= slots.length; step++) {
      final candidate = (from + step) % slots.length;
      if (slots[candidate] == null) return candidate;
    }
    return from;
  }
}
