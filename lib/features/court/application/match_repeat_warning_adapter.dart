import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Bridges the app's wire models to `vmito_domain`'s plain types.
///
/// The domain package must not know about JSON models — that is what keeps its
/// tests running under bare `dart test`. This file is the only place the two
/// vocabularies meet.
extension CourtDirectionToDomain on CourtDirection {
  PairDirection get asPairDirection => this == CourtDirection.vertical
      ? PairDirection.vertical
      : PairDirection.horizontal;
}

extension MatchTypeToDomain on MatchType {
  CourtFormat get asCourtFormat =>
      this == MatchType.singles ? CourtFormat.singles : CourtFormat.doubles;
}

/// A finished match, reduced to seats.
///
/// Each match keeps **its own** court direction: teams were decided by the
/// geometry of the court it was played on, so replaying it under a different
/// direction would count the wrong pairings.
PlayedMatch toPlayedMatch(Match match, {required CourtDirection direction}) =>
    PlayedMatch(
      direction: direction.asPairDirection,
      players: [
        for (final seat in match.players)
          PositionedPlayer(
            id: seat.playerId,
            position: seat.position,
            name: seat.player?.name,
            playerNumber: seat.player?.playerNumber,
          ),
      ],
    );

/// The line-up being considered, as seats.
List<PositionedPlayer> toPositionedPlayers(Iterable<SessionPlayer?> seats) => [
  for (final (index, player) in seats.indexed)
    if (player != null)
      PositionedPlayer(
        id: player.id,
        // The selection court indexes by seat, so the list position *is* the
        // seat — a player picked into slot 2 has no `position` field yet.
        position: index,
        name: player.name,
        playerNumber: player.playerNumber,
      ),
];
