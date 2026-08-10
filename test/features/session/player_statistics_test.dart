import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  test('parses the backend player statistics payload and nullable fields', () {
    final statistics = PlayerStatistics.fromJson({
      'playerId': 'p1',
      'playerNumber': 7,
      'name': 'An',
      'gender': 'FEMALE',
      'level': 4,
      'totalMatches': 5,
      'regularMatches': 4,
      'extraMatches': 1,
      'wins': 3,
      'losses': 2,
      'winRate': 60,
      'averageScore': 0,
      'scoredMatches': 3,
      'averagePointDifferential': 2.5,
      'totalPlayTime': 75,
      'totalWaitTime': 20,
      'totalShuttlecocks': null,
      'status': 'PLAYING',
    });

    expect(statistics.playerId, 'p1');
    expect(statistics.gender, Gender.female);
    expect(statistics.status, PlayerStatus.playing);
    expect(statistics.averagePointDifferential, 2.5);
    expect(statistics.totalShuttlecocks, isNull);
  });
}
