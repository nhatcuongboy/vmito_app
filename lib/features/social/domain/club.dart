class ClubVenue {
  const ClubVenue({
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory ClubVenue.fromJson(Map<String, dynamic> json) => ClubVenue(
    name: json['name'] as String? ?? '',
    address: (json['newAddress'] ?? json['address']) as String? ?? '',
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble(),
  );

  final String name;
  final String address;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;
}

class ClubSchedule {
  const ClubSchedule({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  factory ClubSchedule.fromJson(Map<String, dynamic> json) => ClubSchedule(
    dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
  );

  final int dayOfWeek;
  final String startTime;
  final String endTime;
}

class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.joinPolicy,
    this.description,
    this.image,
    this.logo,
    this.location,
    this.hostName,
    this.defaultVenue,
    this.schedules = const [],
    this.requiredLevels = const [],
    this.isFavorite = false,
    this.isPublic = true,
    this.maxMembers,
    this.status = 'APPROVED',
  });

  factory ClubSummary.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>?;
    final venue = json['defaultVenue'] as Map<String, dynamic>?;
    final rawSchedules = json['schedules'] as List<dynamic>? ?? const [];
    final rawLevels = json['requiredLevels'] as List<dynamic>? ?? const [];
    return ClubSummary(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
      joinPolicy: json['joinPolicy'] as String? ?? 'APPROVAL_REQUIRED',
      description: json['description'] as String?,
      image: json['image'] as String?,
      logo: json['logo'] as String?,
      location: json['location'] as String?,
      hostName: host?['name'] as String? ?? json['hostName'] as String?,
      defaultVenue: venue == null ? null : ClubVenue.fromJson(venue),
      schedules: rawSchedules
          .whereType<Map<String, dynamic>>()
          .map(ClubSchedule.fromJson)
          .toList(growable: false),
      requiredLevels: rawLevels
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      isFavorite: json['isFavorite'] as bool? ?? false,
      isPublic: json['isPublic'] as bool? ?? true,
      maxMembers: (json['maxMembers'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'APPROVED',
    );
  }

  final String id;
  final String name;
  final int memberCount;
  final String joinPolicy;
  final String? description;
  final String? image;
  final String? logo;
  final String? location;
  final String? hostName;
  final ClubVenue? defaultVenue;
  final List<ClubSchedule> schedules;
  final List<int> requiredLevels;
  final bool isFavorite;
  final bool isPublic;
  final int? maxMembers;
  final String status;

  String? get heroImage => image ?? logo;
  bool get isInvitationOnly => joinPolicy == 'INVITATION_ONLY';
}

class ClubDraft {
  const ClubDraft({
    required this.name,
    required this.joinPolicy,
    required this.isPublic,
    this.description,
    this.location,
    this.maxMembers,
  });

  final String name;
  final String joinPolicy;
  final bool isPublic;
  final String? description;
  final String? location;
  final int? maxMembers;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'joinPolicy': joinPolicy,
    'isPublic': isPublic,
    if (description != null) 'description': description!.trim(),
    if (location != null) 'location': location!.trim(),
    'maxMembers': maxMembers,
  };
}

class ClubMember {
  const ClubMember({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.image,
    this.level,
  });

  factory ClubMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ClubMember(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      image: user['image'] as String?,
      level: (user['level'] as num?)?.toInt(),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? image;
  final int? level;
}

class ClubJoinRequest {
  const ClubJoinRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.createdAt,
    this.message,
    this.userImage,
  });

  factory ClubJoinRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ClubJoinRequest(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      userName: user['name'] as String? ?? '',
      userEmail: user['email'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      message: json['message'] as String?,
      userImage: user['image'] as String?,
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime createdAt;
  final String? message;
  final String? userImage;
}

class ClubAnnouncement {
  const ClubAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    this.authorName,
    this.pinnedUntil,
  });

  factory ClubAnnouncement.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    return ClubAnnouncement(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      authorName: author?['name'] as String?,
      pinnedUntil: DateTime.tryParse(json['pinnedUntil'] as String? ?? ''),
    );
  }

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? authorName;
  final DateTime? pinnedUntil;
}

class ClubUserSearchResult {
  const ClubUserSearchResult({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory ClubUserSearchResult.fromJson(Map<String, dynamic> json) =>
      ClubUserSearchResult(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        image: json['image'] as String?,
      );

  final String id;
  final String name;
  final String email;
  final String? image;
}

class ClubPage {
  const ClubPage({
    required this.clubs,
    required this.page,
    required this.totalPages,
  });

  factory ClubPage.fromJson(dynamic payload) {
    if (payload is List) {
      final clubs = payload
          .whereType<Map<String, dynamic>>()
          .map(ClubSummary.fromJson)
          .toList(growable: false);
      return ClubPage(clubs: clubs, page: 1, totalPages: 1);
    }
    final json = payload as Map<String, dynamic>;
    final raw =
        (json['items'] ?? json['data'] ?? json['clubs']) as List<dynamic>? ??
        const [];
    return ClubPage(
      clubs: raw
          .whereType<Map<String, dynamic>>()
          .map(ClubSummary.fromJson)
          .toList(growable: false),
      page: (json['page'] as num?)?.toInt() ?? 1,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  final List<ClubSummary> clubs;
  final int page;
  final int totalPages;
}
