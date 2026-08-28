/// One player registration waiting for a host decision.
class PendingJoinRequest {
  const PendingJoinRequest({
    required this.id,
    required this.sessionId,
    required this.sessionName,
    this.playerName,
    this.playerNumber,
    this.level,
    this.venueName,
    this.startTime,
    this.userId,
    this.createdByUserId,
    this.userImage,
    this.createdAt,
  });

  factory PendingJoinRequest.fromJson(Map<String, dynamic> json) {
    final session = json['session'] is Map
        ? Map<String, dynamic>.from(json['session'] as Map)
        : const <String, dynamic>{};
    final venue = session['venue'] is Map
        ? Map<String, dynamic>.from(session['venue'] as Map)
        : const <String, dynamic>{};
    final start = session['startTime']?.toString();
    final user = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : const <String, dynamic>{};
    return PendingJoinRequest(
      id: json['id']?.toString() ?? '',
      sessionId:
          json['sessionId']?.toString() ?? session['id']?.toString() ?? '',
      sessionName: session['name']?.toString() ?? '',
      playerName: json['name']?.toString() ?? user['name']?.toString(),
      playerNumber: (json['playerNumber'] as num?)?.toInt(),
      level: (json['level'] as num?)?.toInt(),
      venueName: venue['name']?.toString(),
      startTime: start == null ? null : DateTime.tryParse(start),
      userId: json['userId']?.toString() ?? user['id']?.toString(),
      createdByUserId: json['createdByUserId']?.toString(),
      userImage: user['image']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  final String id;
  final String sessionId;
  final String sessionName;
  final String? playerName;
  final int? playerNumber;
  final int? level;
  final String? venueName;
  final DateTime? startTime;
  final String? userId;
  final String? createdByUserId;
  final String? userImage;
  final DateTime? createdAt;

  String get groupKey {
    final ownerId = createdByUserId ?? userId;
    return ownerId == null || ownerId.isEmpty ? id : '$ownerId-$sessionId';
  }
}
