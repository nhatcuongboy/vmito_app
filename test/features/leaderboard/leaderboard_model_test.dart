import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

void main() {
  test('parses leaderboard response and nullable user fields', () {
    final page = LeaderboardPage.fromJson({
      'sport': 'BADMINTON',
      'period': 'month',
      'board': 'player',
      'periodKey': '2026-08',
      'periodStart': '2026-07-31T17:00:00.000Z',
      'periodEnd': '2026-08-31T17:00:00.000Z',
      'isCurrentPeriod': true,
      'page': 1.0,
      'limit': 20.0,
      'total': 1.0,
      'totalPages': 1.0,
      'entries': [
        {
          'rank': 1.0,
          'points': 120.0,
          'user': {'id': 'u1', 'name': null, 'image': null, 'level': null},
          'tier': 'DIAMOND',
          'totalPoints': 10120.0,
          'matchesWon': 9.0,
          'matchesPlayed': 10.0,
        },
      ],
    });

    expect(page.period, LeaderboardPeriod.month);
    expect(page.periodEnd, DateTime.utc(2026, 8, 31, 17));
    expect(page.entries.single.tier, RankingTier.diamond);
    expect(page.entries.single.user.name, isNull);
    expect(page.entries.single.user.level, isNull);
    expect(page.entries.single.points, 120);
  });

  test('unknown tier safely falls back to bronze', () {
    expect(RankingTier.fromWire('NEW_TIER'), RankingTier.bronze);
  });
}
