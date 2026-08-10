import 'package:vmito_app/shared/models/session_player.dart';

class PlayerDetail {
  const PlayerDetail({
    required this.id,
    required this.playerNumber,
    required this.status,
    required this.currentWaitTime,
    required this.totalWaitTime,
    required this.matchesPlayed,
    this.name,
    this.gender,
    this.level,
    this.levelDescription,
    this.phone,
    this.desire,
    this.userId,
    this.joinCode,
    this.currentCourtName,
  });

  factory PlayerDetail.fromJson(Map<String, dynamic> json) {
    final court = json['currentCourt'] as Map<String, dynamic>?;
    final courtNumber = (court?['courtNumber'] as num?)?.toInt();
    return PlayerDetail(
      id: json['id'] as String? ?? '',
      playerNumber: (json['playerNumber'] as num?)?.toInt() ?? 0,
      name: json['name'] as String?,
      gender: switch (json['gender']) {
        'MALE' => Gender.male,
        'FEMALE' => Gender.female,
        'OTHER' || 'PREFER_NOT_TO_SAY' => Gender.other,
        _ => null,
      },
      level: (json['level'] as num?)?.toInt(),
      levelDescription: json['levelDescription'] as String?,
      phone: json['phone'] as String?,
      desire: json['desire'] as String?,
      userId: json['userId'] as String?,
      joinCode: json['joinCode'] as String?,
      status: switch (json['status']) {
        'PLAYING' => PlayerStatus.playing,
        'FINISHED' => PlayerStatus.finished,
        'READY' => PlayerStatus.ready,
        'INACTIVE' => PlayerStatus.inactive,
        _ => PlayerStatus.waiting,
      },
      currentWaitTime: (json['currentWaitTime'] as num?)?.toInt() ?? 0,
      totalWaitTime: (json['totalWaitTime'] as num?)?.toInt() ?? 0,
      matchesPlayed: (json['matchesPlayed'] as num?)?.toInt() ?? 0,
      currentCourtName:
          court?['courtName'] as String? ??
          (courtNumber == null ? null : '$courtNumber'),
    );
  }

  final String id;
  final int playerNumber;
  final String? name;
  final Gender? gender;
  final int? level;
  final String? levelDescription;
  final String? phone;
  final String? desire;
  final String? userId;
  final String? joinCode;
  final PlayerStatus status;
  final int currentWaitTime;
  final int totalWaitTime;
  final int matchesPlayed;
  final String? currentCourtName;
}
