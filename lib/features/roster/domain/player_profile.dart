import 'package:vmito_app/shared/models/session_player.dart';

enum PlayerProfileStatus {
  active,
  promoted,
  archived,
}

extension PlayerProfileStatusX on PlayerProfileStatus {
  String get wireValue => switch (this) {
    PlayerProfileStatus.active => 'ACTIVE',
    PlayerProfileStatus.promoted => 'PROMOTED',
    PlayerProfileStatus.archived => 'ARCHIVED',
  };

  static PlayerProfileStatus fromString(String? value) =>
      switch (value?.toUpperCase()) {
        'PROMOTED' => PlayerProfileStatus.promoted,
        'ARCHIVED' => PlayerProfileStatus.archived,
        _ => PlayerProfileStatus.active,
      };
}

class PlayerProfileClub {
  const PlayerProfileClub({
    required this.id,
    required this.name,
    this.color,
    this.logo,
  });

  factory PlayerProfileClub.fromJson(Map<String, dynamic> json) =>
      PlayerProfileClub(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        color: json['color'] as String?,
        logo: json['logo'] as String?,
      );

  final String id;
  final String name;
  final String? color;
  final String? logo;
}

class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.name,
    this.gender,
    this.phone,
    this.level,
    this.notes,
    this.status = PlayerProfileStatus.active,
    this.clubId,
    this.club,
    this.linkedUserId,
    this.promotedAt,
    this.totalSessions = 0,
    this.lastPlayedAt,
    this.lastSessionName,
    this.points = 0,
    this.tier = 'BRONZE',
    this.createdAt,
    this.updatedAt,
  });

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final clubJson = json['club'] as Map<String, dynamic>?;
    return PlayerProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      gender: switch ((json['gender'] as String?)?.toUpperCase()) {
        'FEMALE' => Gender.female,
        'OTHER' => Gender.other,
        'MALE' => Gender.male,
        _ => null,
      },
      phone: json['phone'] as String?,
      level: (json['level'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      status: PlayerProfileStatusX.fromString(json['status'] as String?),
      clubId: json['clubId'] as String?,
      club: clubJson != null ? PlayerProfileClub.fromJson(clubJson) : null,
      linkedUserId:
          json['linkedUserId'] as String? ?? json['userId'] as String?,
      promotedAt: json['promotedAt'] != null
          ? DateTime.tryParse(json['promotedAt'] as String)
          : null,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.tryParse(json['lastPlayedAt'] as String)
          : null,
      lastSessionName: json['lastSessionName'] as String?,
      points: (json['points'] as num?)?.toInt() ?? 0,
      tier: json['tier'] as String? ?? 'BRONZE',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  final String id;
  final String name;
  final Gender? gender;
  final String? phone;
  final int? level;
  final String? notes;
  final PlayerProfileStatus status;
  final String? clubId;
  final PlayerProfileClub? club;
  final String? linkedUserId;
  final DateTime? promotedAt;
  final int totalSessions;
  final DateTime? lastPlayedAt;
  final String? lastSessionName;
  final int points;
  final String tier;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive => status == PlayerProfileStatus.active;
  bool get isPromoted => status == PlayerProfileStatus.promoted;
  bool get isArchived => status == PlayerProfileStatus.archived;
  bool get isClubMember => clubId != null && clubId!.isNotEmpty;
}
