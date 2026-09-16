import 'package:vmito_app/shared/models/session_player.dart';

class ProfilePointsState {
  const ProfilePointsState({
    required this.sport,
    required this.totalPoints,
    required this.tier,
  });

  factory ProfilePointsState.fromJson(Map<String, dynamic> json) =>
      ProfilePointsState(
        sport: json['sport'] as String? ?? 'BADMINTON',
        totalPoints: (json['totalPoints'] as num?)?.toInt() ?? 0,
        tier: json['tier'] as String? ?? 'BRONZE',
      );

  final String sport;
  final int totalPoints;
  final String tier;
}

class ProfileSessionHistoryItem {
  const ProfileSessionHistoryItem({
    required this.sessionId,
    required this.sessionName,
    required this.sportType,
    this.startTime,
    required this.status,
    this.playerNumber,
    this.matchesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
  });

  factory ProfileSessionHistoryItem.fromJson(Map<String, dynamic> json) =>
      ProfileSessionHistoryItem(
        sessionId: json['sessionId'] as String? ?? '',
        sessionName: json['sessionName'] as String? ?? '',
        sportType: json['sportType'] as String? ?? 'BADMINTON',
        startTime: json['startTime'] != null
            ? DateTime.tryParse(json['startTime'] as String)
            : null,
        status: json['status'] as String? ?? '',
        playerNumber: (json['playerNumber'] as num?)?.toInt(),
        matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        draws: (json['draws'] as num?)?.toInt() ?? 0,
      );

  final String sessionId;
  final String sessionName;
  final String sportType;
  final DateTime? startTime;
  final String status;
  final int? playerNumber;
  final int matchesPlayed;
  final int wins;
  final int losses;
  final int draws;
}

class PlayerProfileStats {
  const PlayerProfileStats({
    required this.profileId,
    required this.name,
    this.gender,
    this.level,
    required this.status,
    this.linkedUserId,
    this.totalSessions = 0,
    this.totalMatches = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRate = 0,
    this.pointsStates = const [],
    this.sessionHistory = const [],
  });

  factory PlayerProfileStats.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['pointsStates'] as List<dynamic>? ?? const [];
    final rawHistory = json['sessionHistory'] as List<dynamic>? ?? const [];
    return PlayerProfileStats(
      profileId: json['profileId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      gender: switch ((json['gender'] as String?)?.toUpperCase()) {
        'FEMALE' => Gender.female,
        'OTHER' => Gender.other,
        'MALE' => Gender.male,
        _ => null,
      },
      level: (json['level'] as num?)?.toInt(),
      status: json['status'] as String? ?? '',
      linkedUserId: json['linkedUserId'] as String?,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      totalMatches: (json['totalMatches'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      winRate: (json['winRate'] as num?)?.toInt() ?? 0,
      pointsStates: rawPoints
          .whereType<Map<String, dynamic>>()
          .map(ProfilePointsState.fromJson)
          .toList(growable: false),
      sessionHistory: rawHistory
          .whereType<Map<String, dynamic>>()
          .map(ProfileSessionHistoryItem.fromJson)
          .toList(growable: false),
    );
  }

  final String profileId;
  final String name;
  final Gender? gender;
  final int? level;
  final String status;
  final String? linkedUserId;
  final int totalSessions;
  final int totalMatches;
  final int wins;
  final int losses;
  final int draws;
  final int winRate;
  final List<ProfilePointsState> pointsStates;
  final List<ProfileSessionHistoryItem> sessionHistory;

  ProfilePointsState? get badmintonPoints => pointsStates.cast<ProfilePointsState?>().firstWhere(
    (item) => item?.sport == 'BADMINTON',
    orElse: () => null,
  );
}
