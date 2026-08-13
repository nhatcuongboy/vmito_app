import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard_periods.dart';

void main() {
  test('week starts on Monday in Vietnam time', () {
    final periods = recentLeaderboardPeriods(
      LeaderboardPeriod.week,
      now: DateTime.utc(2026, 8, 9, 16), // Sunday 23:00 in Vietnam.
    );

    expect(periods.first.key, '2026-08-03');
    expect(periods.first.week, 32);
    expect(periods[1].key, '2026-07-27');
  });

  test('crossing UTC midnight uses the Vietnam calendar day', () {
    final periods = recentLeaderboardPeriods(
      LeaderboardPeriod.week,
      now: DateTime.utc(2026, 8, 9, 18), // Monday 01:00 in Vietnam.
    );

    expect(periods.first.key, '2026-08-10');
  });

  test('month and season options cross year boundaries', () {
    final now = DateTime.utc(2026, 0, 31, 18); // 2026-01-01 01:00 VN.
    final months = recentLeaderboardPeriods(LeaderboardPeriod.month, now: now);
    final seasons = recentLeaderboardPeriods(
      LeaderboardPeriod.season,
      now: now,
    );

    expect(months.first.key, '2026-01');
    expect(months[1].key, '2025-12');
    expect(seasons.first.key, '2026-S1');
    expect(seasons[1].key, '2025-S4');
  });

  test('all-time has no historical options', () {
    expect(recentLeaderboardPeriods(LeaderboardPeriod.all), isEmpty);
  });
}
