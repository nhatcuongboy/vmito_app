class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.joinedSessionsCount,
    this.image,
    this.coverPhoto,
    this.gender,
    this.level,
    this.levelDescription,
  });

  factory PublicProfile.fromJson(Map<String, dynamic> json) => PublicProfile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Vmito',
    role: json['role'] as String? ?? 'PLAYER',
    joinedSessionsCount: (json['joinedSessionsCount'] as num?)?.toInt() ?? 0,
    image: json['image'] as String?,
    coverPhoto: json['coverPhoto'] as String?,
    gender: json['gender'] as String?,
    level: (json['level'] as num?)?.toInt(),
    levelDescription: json['levelDescription'] as String?,
  );

  final String id;
  final String name;
  final String role;
  final int joinedSessionsCount;
  final String? image;
  final String? coverPhoto;
  final String? gender;
  final int? level;
  final String? levelDescription;
}

class RatingStats {
  const RatingStats({required this.average, required this.total});

  factory RatingStats.fromJson(Map<String, dynamic> json) => RatingStats(
    average: (json['averageRating'] as num?)?.toDouble() ?? 0,
    total: (json['totalRatings'] as num?)?.toInt() ?? 0,
  );

  final double average;
  final int total;
}

class PlayerRating {
  const PlayerRating({
    required this.id,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.raterName,
    this.raterImage,
  });

  factory PlayerRating.fromJson(Map<String, dynamic> json) {
    final rater = json['rater'] as Map<String, dynamic>?;
    return PlayerRating(
      id: json['id'] as String? ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      comment: json['comment'] as String?,
      raterName: rater?['name'] as String?,
      raterImage: rater?['image'] as String?,
    );
  }

  final String id;
  final int rating;
  final DateTime createdAt;
  final String? comment;
  final String? raterName;
  final String? raterImage;
}

class RatingEligibility {
  const RatingEligibility({
    required this.canRateHost,
    required this.canRatePlayers,
  });

  factory RatingEligibility.fromJson(Map<String, dynamic> json) =>
      RatingEligibility(
        canRateHost: json['canRateHost'] as bool? ?? false,
        canRatePlayers: (json['canRatePlayers'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );

  final bool canRateHost;
  final List<String> canRatePlayers;

  bool get isEmpty => !canRateHost && canRatePlayers.isEmpty;
}
