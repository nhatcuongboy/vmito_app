import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

const leaderboardPeriods = <LeaderboardPeriod>[
  LeaderboardPeriod.week,
  LeaderboardPeriod.month,
  LeaderboardPeriod.season,
  LeaderboardPeriod.all,
];

const _vietnamOffset = Duration(hours: 7);
const _seasonMonths = 3;

class LeaderboardPeriodOption {
  const LeaderboardPeriodOption({
    required this.key,
    required this.isCurrent,
    required this.start,
    required this.year,
    required this.month,
    required this.week,
    required this.season,
  });

  final String key;
  final bool isCurrent;
  final DateTime start;
  final int year;
  final int month;
  final int week;
  final int season;
}

List<LeaderboardPeriodOption> recentLeaderboardPeriods(
  LeaderboardPeriod period, {
  int count = 6,
  DateTime? now,
}) {
  if (period == LeaderboardPeriod.all) return const [];
  final vietnamNow = _toVietnamWallClock((now ?? DateTime.now()).toUtc());
  final currentStart = _startOfPeriod(period, vietnamNow);

  return List.generate(count, (index) {
    final start = _shiftPeriod(period, currentStart, index);
    return LeaderboardPeriodOption(
      key: _periodKey(period, start),
      isCurrent: index == 0,
      start: start.subtract(_vietnamOffset),
      year: start.year,
      month: start.month,
      week: _isoWeek(start),
      season: ((start.month - 1) ~/ _seasonMonths) + 1,
    );
  }, growable: false);
}

DateTime _toVietnamWallClock(DateTime utc) => utc.add(_vietnamOffset);

DateTime _wallDate(int year, int month, int day) =>
    DateTime.utc(year, month, day);

DateTime _weekStart(DateTime wallClock) => _wallDate(
  wallClock.year,
  wallClock.month,
  wallClock.day - (wallClock.weekday - DateTime.monday),
);

DateTime _startOfPeriod(
  LeaderboardPeriod period,
  DateTime wallClock,
) => switch (period) {
  LeaderboardPeriod.week => _weekStart(wallClock),
  LeaderboardPeriod.month => _wallDate(wallClock.year, wallClock.month, 1),
  LeaderboardPeriod.season => _wallDate(
    wallClock.year,
    ((wallClock.month - 1) ~/ _seasonMonths) * _seasonMonths + 1,
    1,
  ),
  LeaderboardPeriod.year ||
  LeaderboardPeriod.all => _wallDate(wallClock.year, 1, 1),
};

DateTime _shiftPeriod(
  LeaderboardPeriod period,
  DateTime start,
  int steps,
) => switch (period) {
  LeaderboardPeriod.week => start.subtract(Duration(days: steps * 7)),
  LeaderboardPeriod.month => _wallDate(start.year, start.month - steps, 1),
  LeaderboardPeriod.season => _wallDate(
    start.year,
    start.month - steps * _seasonMonths,
    1,
  ),
  LeaderboardPeriod.year ||
  LeaderboardPeriod.all => _wallDate(start.year - steps, 1, 1),
};

String _periodKey(LeaderboardPeriod period, DateTime start) {
  final year = start.year;
  return switch (period) {
    LeaderboardPeriod.week => '$year-${_pad(start.month)}-${_pad(start.day)}',
    LeaderboardPeriod.month => '$year-${_pad(start.month)}',
    LeaderboardPeriod.season =>
      '$year-S${((start.month - 1) ~/ _seasonMonths) + 1}',
    LeaderboardPeriod.year || LeaderboardPeriod.all => '$year',
  };
}

int _isoWeek(DateTime wallClock) {
  final thursday = _weekStart(wallClock).add(const Duration(days: 3));
  final firstThursday = _wallDate(thursday.year, 1, 4);
  final difference = thursday.difference(_weekStart(firstThursday)).inDays;
  return (difference / 7).round() + 1;
}

String _pad(int value) => value.toString().padLeft(2, '0');
