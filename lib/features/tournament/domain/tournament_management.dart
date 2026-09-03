enum TournamentPermission {
  results('RESULTS'),
  schedule('SCHEDULE'),
  participants('PARTICIPANTS'),
  structure('STRUCTURE');

  const TournamentPermission(this.wireValue);
  final String wireValue;

  static TournamentPermission? tryFromWire(String? value) => switch (value) {
    'RESULTS' => results,
    'SCHEDULE' => schedule,
    'PARTICIPANTS' => participants,
    'STRUCTURE' => structure,
    _ => null,
  };
}

class TournamentMyAccess {
  const TournamentMyAccess({
    required this.tournamentId,
    required this.isHost,
    required this.isAdmin,
    required this.permissions,
  });

  factory TournamentMyAccess.fromJson(Map<String, dynamic> json) =>
      TournamentMyAccess(
        tournamentId: json['tournamentId'] as String? ?? '',
        isHost: json['isHost'] as bool? ?? false,
        isAdmin: json['isAdmin'] as bool? ?? false,
        permissions: (json['permissions'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .map(TournamentPermission.tryFromWire)
            .whereType<TournamentPermission>()
            .toSet(),
      );

  final String tournamentId;
  final bool isHost;
  final bool isAdmin;
  final Set<TournamentPermission> permissions;

  bool get isHostOrAdmin => isHost || isAdmin;
  bool get canManage => isHostOrAdmin || permissions.isNotEmpty;
  bool allows(TournamentPermission permission) =>
      isHostOrAdmin || permissions.contains(permission);
}

class TournamentManagerUser {
  const TournamentManagerUser({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory TournamentManagerUser.fromJson(Map<String, dynamic> json) =>
      TournamentManagerUser(
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

class TournamentManager {
  const TournamentManager({
    required this.id,
    required this.tournamentId,
    required this.userId,
    required this.permissions,
    this.user,
  });

  factory TournamentManager.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    return TournamentManager(
      id: json['id'] as String? ?? '',
      tournamentId: json['tournamentId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      permissions: (json['permissions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(TournamentPermission.tryFromWire)
          .whereType<TournamentPermission>()
          .toSet(),
      user: user is Map
          ? TournamentManagerUser.fromJson(user.cast<String, dynamic>())
          : null,
    );
  }

  final String id;
  final String tournamentId;
  final String userId;
  final Set<TournamentPermission> permissions;
  final TournamentManagerUser? user;
}

class TournamentUserOption {
  const TournamentUserOption({
    required this.id,
    required this.name,
    required this.email,
  });

  factory TournamentUserOption.fromJson(Map<String, dynamic> json) =>
      TournamentUserOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  final String id;
  final String name;
  final String email;
}

class TournamentImageAsset {
  const TournamentImageAsset({
    required this.id,
    required this.url,
    required this.publicId,
  });

  factory TournamentImageAsset.fromJson(Map<String, dynamic> json) =>
      TournamentImageAsset(
        id: json['id'] as String? ?? '',
        url: (json['url'] ?? json['secureUrl']) as String? ?? '',
        publicId:
            (json['publicId'] ?? json['cloudinaryPublicId']) as String? ?? '',
      );

  final String id;
  final String url;
  final String publicId;
}

class DuplicateTournamentDraft {
  const DuplicateTournamentDraft({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.venueId,
    this.copyFormat = true,
    this.copySchedule = false,
    this.copyTeams = false,
    this.copyMatchResults = false,
    this.copyVenues = false,
    this.copyCustomHomePage = false,
  });

  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String? venueId;
  final bool copyFormat;
  final bool copySchedule;
  final bool copyTeams;
  final bool copyMatchResults;
  final bool copyVenues;
  final bool copyCustomHomePage;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'startDate': DateTime.utc(
      startDate.year,
      startDate.month,
      startDate.day,
    ).toIso8601String(),
    'endDate': DateTime.utc(
      endDate.year,
      endDate.month,
      endDate.day,
    ).toIso8601String(),
    if (venueId?.isNotEmpty ?? false) 'venueId': venueId,
    'copy': {
      'format': copyFormat,
      'schedule': copySchedule,
      'teams': copyTeams,
      'matchResults': copyMatchResults,
      'venues': copyVenues,
      'customHomePage': copyCustomHomePage,
    },
  };
}
