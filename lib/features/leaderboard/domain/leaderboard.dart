enum LeaderboardPeriod {
  week('week'),
  month('month'),
  season('season'),
  year('year'),
  all('all');

  const LeaderboardPeriod(this.wireValue);

  final String wireValue;

  static LeaderboardPeriod fromWire(String? value) => values.firstWhere(
    (period) => period.wireValue == value,
    orElse: () => LeaderboardPeriod.week,
  );
}

enum RankingTier {
  bronze('BRONZE'),
  silver('SILVER'),
  gold('GOLD'),
  platinum('PLATINUM'),
  diamond('DIAMOND');

  const RankingTier(this.wireValue);

  final String wireValue;

  static RankingTier fromWire(String? value) => values.firstWhere(
    (tier) => tier.wireValue == value,
    orElse: () => RankingTier.bronze,
  );
}

class LeaderboardUser {
  const LeaderboardUser({
    required this.id,
    this.name,
    this.image,
    this.level,
  });

  factory LeaderboardUser.fromJson(Map<String, dynamic> json) =>
      LeaderboardUser(
        id: json['id'] as String,
        name: json['name'] as String?,
        image: json['image'] as String?,
        level: (json['level'] as num?)?.toInt(),
      );

  final String id;
  final String? name;
  final String? image;
  final int? level;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.points,
    required this.user,
    required this.tier,
    required this.totalPoints,
    required this.matchesWon,
    required this.matchesPlayed,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        rank: (json['rank'] as num).toInt(),
        points: (json['points'] as num).toInt(),
        user: LeaderboardUser.fromJson(
          json['user'] as Map<String, dynamic>,
        ),
        tier: RankingTier.fromWire(json['tier'] as String?),
        totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
        matchesWon: (json['matchesWon'] as num?)?.toInt() ?? 0,
        matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      );

  final int rank;
  final int points;
  final LeaderboardUser user;
  final RankingTier tier;
  final int totalPoints;
  final int matchesWon;
  final int matchesPlayed;
}

class LeaderboardPage {
  const LeaderboardPage({
    required this.sport,
    required this.period,
    required this.board,
    required this.isCurrentPeriod,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.entries,
    this.periodKey,
    this.periodStart,
    this.periodEnd,
  });

  factory LeaderboardPage.fromJson(Map<String, dynamic> json) =>
      LeaderboardPage(
        sport: json['sport'] as String? ?? 'BADMINTON',
        period: LeaderboardPeriod.fromWire(json['period'] as String?),
        board: json['board'] as String? ?? 'player',
        periodKey: json['periodKey'] as String?,
        periodStart: DateTime.tryParse(json['periodStart'] as String? ?? ''),
        periodEnd: DateTime.tryParse(json['periodEnd'] as String? ?? ''),
        isCurrentPeriod: json['isCurrentPeriod'] as bool? ?? true,
        page: (json['page'] as num?)?.toInt() ?? 1,
        limit: (json['limit'] as num?)?.toInt() ?? 20,
        total: (json['total'] as num?)?.toInt() ?? 0,
        totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
        entries: (json['entries'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(LeaderboardEntry.fromJson)
            .toList(growable: false),
      );

  final String sport;
  final LeaderboardPeriod period;
  final String board;
  final String? periodKey;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final bool isCurrentPeriod;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final List<LeaderboardEntry> entries;
}

/// One row of `GET /leaderboard/me`. `rank` is null when the user has no point
/// transactions in the period at all.
class MyPeriodRank {
  const MyPeriodRank({
    required this.period,
    required this.points,
    this.rank,
  });

  factory MyPeriodRank.fromJson(Map<String, dynamic> json) => MyPeriodRank(
    period: LeaderboardPeriod.fromWire(json['period'] as String?),
    points: (json['points'] as num?)?.toInt() ?? 0,
    rank: (json['rank'] as num?)?.toInt(),
  );

  final LeaderboardPeriod period;
  final int points;
  final int? rank;
}

/// `GET /leaderboard/me` answers for every period at once, and only ever for
/// the *current* one — `LeaderboardService.getUserRank` derives its window from
/// `periodStart(period)` and takes no `periodKey`. There is no tier in this
/// payload either, so callers that fall back to it cannot show a tier badge.
class MyLeaderboardRanks {
  const MyLeaderboardRanks({required this.sport, required this.ranks});

  factory MyLeaderboardRanks.fromJson(Map<String, dynamic> json) =>
      MyLeaderboardRanks(
        sport: json['sport'] as String? ?? 'BADMINTON',
        ranks: (json['ranks'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MyPeriodRank.fromJson)
            .toList(growable: false),
      );

  final String sport;
  final List<MyPeriodRank> ranks;

  MyPeriodRank? forPeriod(LeaderboardPeriod period) {
    for (final rank in ranks) {
      if (rank.period == period) return rank;
    }
    return null;
  }
}
