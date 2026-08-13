import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

/// Pins the shapes `GET /sessions/:id` actually sends for a court.
///
/// Every expectation here was read off `vmito-be` rather than off the web app's
/// `types.ts`, which is wrong about two of them.
void main() {
  test('SessionPlayer reads linked user metadata for the detail roster', () {
    final player = SessionPlayer.fromJson({
      'id': 'p1',
      'userId': 'u1',
      'user': {'image': 'https://cdn.example.test/p1.jpg'},
    });

    expect(player.userId, 'u1');
    expect(player.userImage, 'https://cdn.example.test/p1.jpg');
  });

  group('Court.preSelectedPlayers', () {
    // Regression. The field was typed `List<SessionPlayer>`, but the column is
    // `preSelectedPlayers Json?` holding raw `{playerId, position}` pairs, and
    // `sessions.service.ts` spreads the court row so they arrive unresolved.
    // `SessionPlayer.fromJson` then threw on its required `id`, taking the
    // whole session-detail parse down for any host mid-pre-selection.
    test('parses raw {playerId, position} pairs, not players', () {
      final court = Court.fromJson({
        'id': 'court-1',
        'courtNumber': 1,
        'status': 'IN_USE',
        'preSelectedPlayers': [
          {'playerId': 'p9', 'position': 1},
          {'playerId': 'p4', 'position': 0},
        ],
      });

      expect(court.hasPreSelection, isTrue);
      expect(court.preSelectedPlayers.map((s) => s.playerId), ['p9', 'p4']);
      expect(court.preSelectedPlayers.map((s) => s.position), [1, 0]);

      // Why the old typing was fatal, pinned so nobody "simplifies" it back:
      // these entries carry no `id`, so decoding one as a player throws.
      expect(
        () => SessionPlayer.fromJson({'playerId': 'p9', 'position': 1}),
        throwsA(isA<TypeError>()),
      );
    });

    test('a court with no pre-selection sends null, which reads as empty', () {
      final court = Court.fromJson({
        'id': 'court-1',
        'courtNumber': 1,
        'status': 'EMPTY',
        'preSelectedPlayers': null,
      });

      expect(court.preSelectedPlayers, isEmpty);
      expect(court.hasPreSelection, isFalse);
    });

    test('Session resolves the slots against its roster, in slot order', () {
      final session = Session.fromJson({
        'id': 's1',
        'name': 'Kèo test',
        'status': 'IN_PROGRESS',
        'players': [
          {'id': 'p4', 'name': 'Minh', 'playerNumber': 4},
          {'id': 'p9', 'name': 'Bảo', 'playerNumber': 9},
        ],
        'courts': [
          {
            'id': 'court-1',
            'courtNumber': 1,
            'status': 'IN_USE',
            'preSelectedPlayers': [
              {'playerId': 'p9', 'position': 1},
              {'playerId': 'p4', 'position': 0},
            ],
          },
        ],
      });

      final resolved = session.preSelectedPlayersFor(session.courts.single);
      expect(resolved.map((p) => p.name), ['Minh', 'Bảo']);
    });

    test('an id missing from the roster is dropped, not rendered blank', () {
      final session = Session.fromJson({
        'id': 's1',
        'name': 'Kèo test',
        'status': 'IN_PROGRESS',
        'players': [
          {'id': 'p4', 'name': 'Minh'},
        ],
        'courts': [
          {
            'id': 'court-1',
            'courtNumber': 1,
            'status': 'IN_USE',
            'preSelectedPlayers': [
              {'playerId': 'p4', 'position': 0},
              {'playerId': 'gone', 'position': 1},
            ],
          },
        ],
      });

      final resolved = session.preSelectedPlayersFor(session.courts.single);
      expect(resolved.map((p) => p.id), ['p4']);
    });
  });

  group('Court.currentMatch', () {
    test('carries startTime, which is what the elapsed badge counts from', () {
      final court = Court.fromJson({
        'id': 'court-3',
        'courtNumber': 3,
        'status': 'IN_USE',
        'currentMatchId': 'm1',
        'currentMatch': {
          'id': 'm1',
          'sessionId': 's1',
          'courtId': 'court-3',
          'status': 'IN_PROGRESS',
          'startTime': '2026-08-03T10:15:00.000Z',
          'players': [
            {'id': 'mp2', 'playerId': 'p2', 'position': 1},
            {'id': 'mp1', 'playerId': 'p1', 'position': 0},
          ],
        },
      });

      expect(court.currentMatch?.startTime?.toUtc().hour, 10);
      expect(court.currentMatch?.isRunning, isTrue);
      // A running match owns the slot order, not the player rows.
      expect(court.currentMatch?.orderedPlayerIds, ['p1', 'p2']);
      expect(court.orderedPlayerIds, ['p1', 'p2']);
    });

    // `score` and `winnerIds` are `String?` columns holding serialized JSON.
    // `vmito-fe/src/lib/api/types.ts` declares them as `array` and `string[]`;
    // the API does not send that, and typing them that way would throw.
    test('score and winnerIds arrive as strings, not arrays', () {
      final match = Match.fromJson({
        'id': 'm1',
        'sessionId': 's1',
        'courtId': 'c1',
        'status': 'FINISHED',
        'score': '[{"playerId":"p1","score":21}]',
        'winnerIds': 'p1,p2',
        'isDraw': false,
        'shuttlecockCount': 2.5,
      });

      expect(match.score, isA<String>());
      expect(match.winnerIds, isA<String>());
      expect(match.shuttlecockCount, 2.5);
    });
  });

  group('court slot positions', () {
    test('a READY court falls back to courtPosition when no match exists', () {
      final court = Court.fromJson({
        'id': 'court-2',
        'courtNumber': 2,
        'status': 'READY',
        'currentPlayers': [
          {'id': 'p2', 'courtPosition': 1},
          {'id': 'p1', 'courtPosition': 0},
        ],
      });

      expect(court.currentMatch, isNull);
      expect(court.orderedPlayerIds, ['p1', 'p2']);
    });

    test('the backend-normalised `position` wins over `courtPosition`', () {
      // `sessions.service.ts` adds `position` to every court player, resolving
      // it from MatchPlayer for a running match. It is the authoritative one.
      const player = SessionPlayer(id: 'p1', position: 3, courtPosition: 0);
      expect(player.slotPosition, 3);
      expect(const SessionPlayer(id: 'p2', courtPosition: 2).slotPosition, 2);
      expect(const SessionPlayer(id: 'p3').slotPosition, 0);
    });
  });

  group('Court.matchTypeOr', () {
    test('reads the live occupancy, falling back only when empty', () {
      const empty = Court(id: 'c', courtNumber: 1);
      expect(empty.matchTypeOr(MatchType.doubles), MatchType.doubles);
      expect(empty.matchTypeOr(MatchType.singles), MatchType.singles);

      const singles = Court(
        id: 'c',
        courtNumber: 1,
        currentPlayers: [
          SessionPlayer(id: 'a'),
          SessionPlayer(id: 'b'),
        ],
      );
      expect(singles.matchTypeOr(MatchType.doubles), MatchType.singles);

      const doubles = Court(
        id: 'c',
        courtNumber: 1,
        currentPlayers: [
          SessionPlayer(id: 'a'),
          SessionPlayer(id: 'b'),
          SessionPlayer(id: 'c'),
          SessionPlayer(id: 'd'),
        ],
      );
      expect(doubles.matchTypeOr(MatchType.singles), MatchType.doubles);
    });
  });

  group('Session.waitingQueue', () {
    test('WAITING only, longest wait first — the assign gate counts this', () {
      final session = Session.fromJson({
        'id': 's1',
        'name': 'Kèo test',
        'status': 'IN_PROGRESS',
        'defaultMatchType': 'SINGLES',
        'courtColor': '#179a3b',
        'players': [
          {'id': 'a', 'status': 'WAITING', 'currentWaitTime': 5},
          {'id': 'b', 'status': 'READY', 'currentWaitTime': 99},
          {'id': 'c', 'status': 'WAITING', 'currentWaitTime': 26},
          {'id': 'd', 'status': 'PLAYING', 'currentWaitTime': 0},
        ],
      });

      expect(session.waitingQueue.map((p) => p.id), ['c', 'a']);
      // waitingPlayers is the looser one and still includes READY.
      expect(session.waitingPlayers.map((p) => p.id), ['a', 'b', 'c']);
      expect(session.defaultMatchType, MatchType.singles);
      expect(session.courtColor, '#179a3b');
    });
  });
}
