import 'package:vmito_app/shared/models/session_player.dart';

class PlayerStatistics {
  const PlayerStatistics({
    required this.playerId,
    required this.playerNumber,
    required this.totalMatches,
    required this.regularMatches,
    required this.extraMatches,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.averageScore,
    required this.scoredMatches,
    required this.totalPlayTime,
    required this.totalWaitTime,
    required this.status,
    this.name,
    this.gender,
    this.level,
    this.averagePointDifferential,
    this.totalShuttlecocks,
  });

  factory PlayerStatistics.fromJson(Map<String, dynamic> json) =>
      PlayerStatistics(
        playerId: json['playerId'] as String? ?? '',
        playerNumber: (json['playerNumber'] as num?)?.toInt() ?? 0,
        name: json['name'] as String?,
        gender: _gender(json['gender']),
        level: (json['level'] as num?)?.toInt(),
        totalMatches: (json['totalMatches'] as num?)?.toInt() ?? 0,
        regularMatches: (json['regularMatches'] as num?)?.toInt() ?? 0,
        extraMatches: (json['extraMatches'] as num?)?.toInt() ?? 0,
        wins: (json['wins'] as num?)?.toInt() ?? 0,
        losses: (json['losses'] as num?)?.toInt() ?? 0,
        winRate: (json['winRate'] as num?)?.toDouble() ?? 0,
        averageScore: (json['averageScore'] as num?)?.toDouble() ?? 0,
        scoredMatches: (json['scoredMatches'] as num?)?.toInt() ?? 0,
        averagePointDifferential: (json['averagePointDifferential'] as num?)
            ?.toDouble(),
        totalPlayTime: (json['totalPlayTime'] as num?)?.toInt() ?? 0,
        totalWaitTime: (json['totalWaitTime'] as num?)?.toInt() ?? 0,
        totalShuttlecocks: (json['totalShuttlecocks'] as num?)?.toDouble(),
        status: _status(json['status']),
      );

  final String playerId;
  final int playerNumber;
  final String? name;
  final Gender? gender;
  final int? level;
  final int totalMatches;
  final int regularMatches;
  final int extraMatches;
  final int wins;
  final int losses;
  final double winRate;
  final double averageScore;
  final int scoredMatches;
  final double? averagePointDifferential;
  final int totalPlayTime;
  final int totalWaitTime;
  final double? totalShuttlecocks;
  final PlayerStatus status;

  static Gender? _gender(Object? value) => switch (value) {
    'MALE' => Gender.male,
    'FEMALE' => Gender.female,
    'OTHER' || 'PREFER_NOT_TO_SAY' => Gender.other,
    _ => null,
  };

  static PlayerStatus _status(Object? value) => switch (value) {
    'PLAYING' => PlayerStatus.playing,
    'FINISHED' => PlayerStatus.finished,
    'READY' => PlayerStatus.ready,
    'INACTIVE' => PlayerStatus.inactive,
    _ => PlayerStatus.waiting,
  };
}
