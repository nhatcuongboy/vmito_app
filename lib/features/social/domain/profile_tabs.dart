import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

class UserAchievements {
  const UserAchievements({
    this.sport = 'BADMINTON',
    required this.totalPoints,
    this.hostPoints = 0,
    required this.tier,
    required this.ranks,
    required this.stats,
    required this.recentTransactions,
    this.nextTier,
  });
  factory UserAchievements.fromJson(Map<String, dynamic> json) =>
      UserAchievements(
        sport: json['sport'] as String? ?? 'BADMINTON',
        totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
        hostPoints: (json['hostPoints'] as num?)?.toInt() ?? 0,
        tier: RankingTier.fromWire(json['tier'] as String?),
        nextTier: switch (json['nextTier']) {
          final Map<String, dynamic> value => NextTier.fromJson(value),
          _ => null,
        },
        ranks: (json['ranks'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(UserRank.fromJson)
            .toList(growable: false),
        stats: UserAchievementStats.fromJson(
          json['stats'] as Map<String, dynamic>? ?? const {},
        ),
        recentTransactions:
            (json['recentTransactions'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(PointTransaction.fromJson)
                .toList(growable: false),
      );
  final String sport;
  final int totalPoints;
  final int hostPoints;
  final RankingTier tier;
  final NextTier? nextTier;
  final List<UserRank> ranks;
  final UserAchievementStats stats;
  final List<PointTransaction> recentTransactions;
}

class NextTier {
  const NextTier({required this.tier, required this.pointsToNext});

  factory NextTier.fromJson(Map<String, dynamic> json) => NextTier(
    tier: RankingTier.fromWire(json['nextTier'] as String?),
    pointsToNext: (json['pointsToNext'] as num?)?.toInt() ?? 0,
  );

  final RankingTier tier;
  final int pointsToNext;
}

class UserRank {
  const UserRank({
    required this.period,
    required this.rank,
    required this.points,
  });
  factory UserRank.fromJson(Map<String, dynamic> json) => UserRank(
    period: json['period'] as String? ?? 'all',
    rank: (json['rank'] as num?)?.toInt(),
    points: (json['points'] as num?)?.toInt() ?? 0,
  );
  final String period;
  final int? rank;
  final int points;
}

class UserAchievementStats {
  const UserAchievementStats({
    this.wins = 0,
    this.draws = 0,
    this.losses = 0,
    this.matchesPlayed = 0,
    this.sessionsPlayed = 0,
    this.sessionsHosted = 0,
    this.tournamentTitles = 0,
    this.tournamentRunnerUps = 0,
  });
  factory UserAchievementStats.fromJson(Map<String, dynamic> json) =>
      UserAchievementStats(
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
        sessionsPlayed: (json['sessionsPlayed'] as num?)?.toInt() ?? 0,
        sessionsHosted: (json['sessionsHosted'] as num?)?.toInt() ?? 0,
        tournamentTitles: (json['tournamentTitles'] as num?)?.toInt() ?? 0,
        tournamentRunnerUps:
            (json['tournamentRunnerUps'] as num?)?.toInt() ?? 0,
      );
  final int wins;
  final int draws;
  final int losses;
  final int matchesPlayed;
  final int sessionsPlayed;
  final int sessionsHosted;
  final int tournamentTitles;
  final int tournamentRunnerUps;
}

class PointTransaction {
  const PointTransaction({
    required this.id,
    required this.points,
    required this.reason,
    required this.occurredAt,
    this.refType = '',
    this.refId = '',
  });
  factory PointTransaction.fromJson(Map<String, dynamic> json) =>
      PointTransaction(
        id: json['id'] as String? ?? '',
        points: (json['points'] as num?)?.toInt() ?? 0,
        reason: json['reason'] as String? ?? '',
        refType: json['refType'] as String? ?? '',
        refId: json['refId'] as String? ?? '',
        occurredAt:
            DateTime.tryParse(json['occurredAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );
  final String id;
  final int points;
  final String reason;
  final String refType;
  final String refId;
  final DateTime occurredAt;
}

class FavoriteTarget {
  const FavoriteTarget({
    required this.id,
    required this.name,
    this.slug,
    this.image,
    this.subtitle,
  });
  factory FavoriteTarget.fromJson(Map<String, dynamic> json) {
    final venue = json['venue'] as Map<String, dynamic>?;
    final defaultVenue = json['defaultVenue'] as Map<String, dynamic>?;
    final host = json['host'] as Map<String, dynamic>?;
    return FavoriteTarget(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      image: (json['coverPhoto'] ?? json['image']) as String?,
      subtitle:
          venue?['name'] as String? ??
          defaultVenue?['name'] as String? ??
          json['address'] as String? ??
          host?['name'] as String?,
    );
  }
  final String id;
  final String name;
  final String? slug;
  final String? image;
  final String? subtitle;
}
