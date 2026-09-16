import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class HostRecentPlayer {
  const HostRecentPlayer({
    required this.profileId,
    required this.name,
    this.gender,
    this.level,
    this.phone,
    this.clubId,
    this.club,
    this.totalSessions = 0,
    this.lastPlayedAt,
    this.isRosterProfile = true,
    this.userId,
  });

  factory HostRecentPlayer.fromJson(Map<String, dynamic> json) {
    final clubJson = json['club'] as Map<String, dynamic>?;
    return HostRecentPlayer(
      profileId: json['profileId'] as String? ?? json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      gender: switch ((json['gender'] as String?)?.toUpperCase()) {
        'FEMALE' => Gender.female,
        'OTHER' => Gender.other,
        'MALE' => Gender.male,
        _ => null,
      },
      level: (json['level'] as num?)?.toInt(),
      phone: json['phone'] as String?,
      clubId: json['clubId'] as String?,
      club: clubJson != null ? PlayerProfileClub.fromJson(clubJson) : null,
      totalSessions: (json['totalSessions'] as num?)?.toInt() ?? 0,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.tryParse(json['lastPlayedAt'] as String)
          : null,
      isRosterProfile: json['isRosterProfile'] as bool? ?? true,
      userId: json['userId'] as String? ?? json['linkedUserId'] as String?,
    );
  }

  final String profileId;
  final String name;
  final Gender? gender;
  final int? level;
  final String? phone;
  final String? clubId;
  final PlayerProfileClub? club;
  final int totalSessions;
  final DateTime? lastPlayedAt;
  final bool isRosterProfile;
  final String? userId;

  bool get isClubMember => clubId != null && clubId!.isNotEmpty;
}
