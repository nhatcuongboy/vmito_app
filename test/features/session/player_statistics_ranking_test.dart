import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/player_statistics_ranking.dart';
import 'package:vmito_app/shared/models/session_player.dart';

PlayerStatistics _player(
  String id, {
  int matches = 4,
  int wins = 2,
  double winRate = 50,
  double? pointDifference,
  Gender? gender,
  int? level,
}) => PlayerStatistics(
  playerId: id,
  playerNumber: int.tryParse(id.substring(1)) ?? 0,
  name: id,
  gender: gender,
  level: level,
  totalMatches: matches,
  regularMatches: matches,
  extraMatches: 0,
  wins: wins,
  losses: matches - wins,
  winRate: winRate,
  averageScore: 0,
  scoredMatches: pointDifference == null ? 0 : matches,
  averagePointDifferential: pointDifference,
  totalPlayTime: 0,
  totalWaitTime: 0,
  status: PlayerStatus.waiting,
);

void main() {
  group('player ranking', () {
    test('uses win rate, wins, point difference and match count in order', () {
      final ranked = rankPlayerStatistics([
        _player('p1', pointDifference: 1),
        _player('p2', pointDifference: 3),
        _player('p3', wins: 3, winRate: 75),
      ]);

      expect(ranked.players.map((e) => e.playerId), ['p3', 'p2', 'p1']);
      expect(ranked.pointDifferentialTiebreakPlayerIds, {'p1', 'p2'});
    });

    test('does not use point difference unless every tied player has it', () {
      final ranked = rankPlayerStatistics([
        _player('p1', matches: 5),
        _player('p2', pointDifference: 10),
      ]);

      expect(ranked.players.first.playerId, 'p1');
      expect(ranked.pointDifferentialEligibleGroups, isEmpty);
    });

    test('MVP threshold is capped at three and supports shared winners', () {
      final players = [
        _player('p1', matches: 8, wins: 4),
        _player('p2', matches: 8, wins: 4),
        _player('p3', matches: 2, winRate: 100),
      ];
      final mvp = calculateMvp(players);

      expect(mvp.minMatches, 3);
      expect(mvp.players.map((e) => e.playerId), ['p1', 'p2']);
    });

    test('gender MVP only considers the selected gender', () {
      final mvp = calculateMvp(
        [
          _player('p1', wins: 4, winRate: 100, gender: Gender.male),
          _player('p2', wins: 3, winRate: 75, gender: Gender.female),
        ],
        gender: Gender.female,
      );

      expect(mvp.players.single.playerId, 'p2');
    });

    test('sorts non-contiguous level ids by their display rank', () {
      final sorted = sortPlayerStatistics(
        [
          _player('p1', level: 1),
          _player('p2', level: 10),
          _player('p3', level: 9),
        ],
        const PlayerStatisticsSort(
          PlayerStatisticsSortField.level,
          StatisticsSortDirection.ascending,
        ),
      );

      expect(sorted.map((e) => e.level), [9, 1, 10]);
    });
  });
}
