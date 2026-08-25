class ClubVenue {
  const ClubVenue({
    this.id,
    required this.name,
    required this.address,
    this.latitude,
    this.longitude,
  });

  factory ClubVenue.fromJson(Map<String, dynamic> json) => ClubVenue(
    id: json['id'] as String?,
    name: json['name'] as String? ?? '',
    address: (json['newAddress'] ?? json['address']) as String? ?? '',
    latitude: (json['lat'] as num?)?.toDouble(),
    longitude: (json['lng'] as num?)?.toDouble(),
  );

  final String? id;
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
    this.notes,
    this.isActive = true,
  });

  factory ClubSchedule.fromJson(Map<String, dynamic> json) => ClubSchedule(
    dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
    startTime: json['startTime'] as String? ?? '',
    endTime: json['endTime'] as String? ?? '',
    notes: json['notes'] as String?,
    isActive: json['isActive'] as bool? ?? true,
  );

  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? notes;
  final bool isActive;
}

class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.joinPolicy,
    this.description,
    this.image,
    this.imagePublicId,
    this.logo,
    this.logoPublicId,
    this.location,
    this.hostName,
    this.defaultVenueId,
    this.defaultVenue,
    this.schedules = const [],
    this.requiredLevels = const [],
    this.isFavorite = false,
    this.isPublic = true,
    this.maxMembers,
    this.status = 'APPROVED',
    this.slug,
    this.images = const [],
    this.imagePublicIds = const [],
    this.socialLinks = const {},
    this.members = const [],
    this.scheduleVenues = const [],
    this.hostId,
    this.hostImage,
    this.distance,
    this.role = 'MEMBER',
    this.joinedAt,
    this.color,
    this.operationalStatus,
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
      imagePublicId: json['imagePublicId'] as String?,
      logo: json['logo'] as String?,
      logoPublicId: json['logoPublicId'] as String?,
      location: json['location'] as String?,
      hostName: host?['name'] as String? ?? json['hostName'] as String?,
      defaultVenueId:
          json['defaultVenueId'] as String? ?? venue?['id'] as String?,
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
      slug: json['slug'] as String?,
      images: (json['images'] as List<dynamic>? ?? const [])
          .map(
            (item) => item is String
                ? item
                : item is Map
                ? item['url'] as String?
                : null,
          )
          .whereType<String>()
          .toList(growable: false),
      imagePublicIds: (json['imagePublicIds'] as List<dynamic>? ?? const [])
          .map(
            (item) => item is String
                ? item
                : item is Map
                ? item['publicId'] as String?
                : null,
          )
          .whereType<String>()
          .toList(growable: false),
      socialLinks:
          (json['socialLinks'] as Map?)?.map(
            (key, value) => MapEntry('$key', '$value'),
          ) ??
          const {},
      members: (json['members'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClubMember.fromJson)
          .toList(growable: false),
      scheduleVenues: (json['scheduleVenues'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ClubVenue.fromJson)
          .toList(growable: false),
      hostId: host?['id'] as String? ?? json['hostId'] as String?,
      hostImage: host?['image'] as String? ?? json['hostImage'] as String?,
      distance: (json['distance'] as num?)?.toDouble(),
      role: json['role'] as String? ?? 'MEMBER',
      joinedAt: DateTime.tryParse(json['joinedAt'] as String? ?? ''),
      color: json['color'] as String?,
      operationalStatus: json['operationalStatus'] as String?,
    );
  }

  final String id;
  final String name;
  final int memberCount;
  final String joinPolicy;
  final String? description;
  final String? image;
  final String? imagePublicId;
  final String? logo;
  final String? logoPublicId;
  final String? location;
  final String? hostName;
  final String? defaultVenueId;
  final ClubVenue? defaultVenue;
  final List<ClubSchedule> schedules;
  final List<int> requiredLevels;
  final bool isFavorite;
  final bool isPublic;
  final int? maxMembers;
  final String status;
  final String? slug;
  final List<String> images;
  final List<String> imagePublicIds;
  final Map<String, String> socialLinks;
  final List<ClubMember> members;
  final List<ClubVenue> scheduleVenues;
  final String? hostId;
  final String? hostImage;
  final double? distance;
  final String role;
  final DateTime? joinedAt;
  final String? color;
  final String? operationalStatus;

  String? get hostUserId => hostId;

  String? get heroImage => image ?? logo;
  List<String> get gallery => [
    if (image?.isNotEmpty ?? false) image!,
    ...images.where((url) => url != image),
  ];
  bool get isInvitationOnly => joinPolicy == 'INVITATION_ONLY';
}

class ClubDraft {
  const ClubDraft({
    required this.name,
    required this.joinPolicy,
    required this.isPublic,
    this.hostName,
    this.hostUserId,
    this.description,
    this.location,
    this.maxMembers,
    this.defaultVenueId,
    this.image,
    this.imagePublicId,
    this.images = const [],
    this.imagePublicIds = const [],
    this.logo,
    this.logoPublicId,
    this.requiredLevels = const [],
    this.schedules = const [],
    this.socialLinks = const {},
  });

  final String name;
  final String joinPolicy;
  final bool isPublic;
  final String? hostName;
  final String? hostUserId;
  final String? description;
  final String? location;
  final int? maxMembers;
  final String? defaultVenueId;
  final String? image;
  final String? imagePublicId;
  final List<String> images;
  final List<String> imagePublicIds;
  final String? logo;
  final String? logoPublicId;
  final List<int> requiredLevels;
  final List<Map<String, dynamic>> schedules;
  final Map<String, String> socialLinks;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    if (hostName?.trim().isNotEmpty ?? false) 'hostName': hostName!.trim(),
    if (hostUserId?.trim().isNotEmpty ?? false) 'hostUserId': hostUserId,
    'joinPolicy': joinPolicy,
    'isPublic': isPublic,
    if (description != null) 'description': description!.trim(),
    if (location != null) 'location': location!.trim(),
    'maxMembers': maxMembers,
    if (defaultVenueId?.trim().isNotEmpty ?? false)
      'defaultVenueId': defaultVenueId!.trim(),
    if (image?.trim().isNotEmpty ?? false) 'image': image,
    if (imagePublicId?.trim().isNotEmpty ?? false)
      'imagePublicId': imagePublicId,
    if (images.isNotEmpty) 'images': images,
    if (imagePublicIds.isNotEmpty) 'imagePublicIds': imagePublicIds,
    if (logo?.trim().isNotEmpty ?? false) 'logo': logo,
    if (logoPublicId?.trim().isNotEmpty ?? false) 'logoPublicId': logoPublicId,
    if (requiredLevels.isNotEmpty) 'requiredLevels': requiredLevels,
    if (schedules.isNotEmpty) 'schedules': schedules,
    if (socialLinks.isNotEmpty) 'socialLinks': socialLinks,
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
    this.status = 'ACTIVE',
    this.gender,
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
      status: json['status'] as String? ?? 'ACTIVE',
      gender: user['gender'] as String?,
    );
  }

  final String id;
  final String userId;
  final String name;
  final String email;
  final String role;
  final String? image;
  final int? level;
  final String status;
  final String? gender;
}

class ClubJoinRequestClub {
  const ClubJoinRequestClub({
    required this.id,
    required this.name,
    this.slug,
    this.image,
    this.hostId,
    this.hostName,
  });

  factory ClubJoinRequestClub.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>?;
    return ClubJoinRequestClub(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String?,
      image: json['image'] as String?,
      hostId: host?['id'] as String?,
      hostName: host?['name'] as String?,
    );
  }

  final String id;
  final String name;
  final String? slug;
  final String? image;
  final String? hostId;
  final String? hostName;
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
    this.clubId = '',
    this.status = 'PENDING',
    this.response,
    this.club,
    this.sessionsPlayedCount,
  });

  factory ClubJoinRequest.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    final club = json['club'] as Map<String, dynamic>?;
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
      clubId: json['clubId'] as String? ?? club?['id'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      response: json['response'] as String?,
      club: club == null ? null : ClubJoinRequestClub.fromJson(club),
      sessionsPlayedCount: (json['sessionsPlayedCount'] as num?)?.toInt(),
    );
  }

  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final DateTime createdAt;
  final String? message;
  final String? userImage;
  final String clubId;
  final String status;
  final String? response;
  final ClubJoinRequestClub? club;
  final int? sessionsPlayedCount;
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

class ClubFeeConfig {
  const ClubFeeConfig({
    this.id,
    this.maleFeeMonthly,
    this.femaleFeeMonthly,
    this.maleFeePerSession,
    this.femaleFeePerSession,
  });

  factory ClubFeeConfig.fromJson(Map<String, dynamic> json) => ClubFeeConfig(
    id: json['id'] as String?,
    maleFeeMonthly: (json['maleFeeMonthly'] as num?)?.toInt(),
    femaleFeeMonthly: (json['femaleFeeMonthly'] as num?)?.toInt(),
    maleFeePerSession: (json['maleFeePerSession'] as num?)?.toInt(),
    femaleFeePerSession: (json['femaleFeePerSession'] as num?)?.toInt(),
  );

  final String? id;
  final int? maleFeeMonthly;
  final int? femaleFeeMonthly;
  final int? maleFeePerSession;
  final int? femaleFeePerSession;

  int? feeForGender(String gender) => gender == 'FEMALE'
      ? femaleFeePerSession ?? maleFeePerSession
      : maleFeePerSession ?? femaleFeePerSession;

  bool get hasPerSessionFee =>
      maleFeePerSession != null || femaleFeePerSession != null;
}

class ClubMonthlyMember {
  const ClubMonthlyMember({
    required this.userId,
    this.id,
    this.name = '',
    this.email = '',
    this.gender,
  });

  factory ClubMonthlyMember.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return ClubMonthlyMember(
      id: json['id'] as String?,
      userId: json['userId'] as String? ?? user['id'] as String? ?? '',
      name: user['name'] as String? ?? '',
      email: user['email'] as String? ?? '',
      gender: user['gender'] as String?,
    );
  }

  final String? id;
  final String userId;
  final String name;
  final String email;
  final String? gender;
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
