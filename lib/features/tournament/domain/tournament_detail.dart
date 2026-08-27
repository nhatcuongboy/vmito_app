import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

enum TournamentCategoryFormat {
  roundRobin,
  singleElimination,
  roundRobinToSingleElimination,
  doubleElimination;

  static TournamentCategoryFormat fromWire(String? value) => switch (value) {
    'SINGLE_ELIMINATION' => TournamentCategoryFormat.singleElimination,
    'ROUND_ROBIN_TO_SE' =>
      TournamentCategoryFormat.roundRobinToSingleElimination,
    'DOUBLE_ELIMINATION' => TournamentCategoryFormat.doubleElimination,
    _ => TournamentCategoryFormat.roundRobin,
  };
}

enum TournamentRegistrationMode {
  individual,
  team;

  static TournamentRegistrationMode fromWire(String? value) =>
      value == 'INDIVIDUAL' ? individual : team;
}

enum TournamentMatchStatus {
  scheduled,
  inProgress,
  finished,
  cancelled;

  static TournamentMatchStatus fromWire(String? value) => switch (value) {
    'IN_PROGRESS' => TournamentMatchStatus.inProgress,
    'FINISHED' => TournamentMatchStatus.finished,
    'CANCELLED' => TournamentMatchStatus.cancelled,
    _ => TournamentMatchStatus.scheduled,
  };
}

class TournamentDetail {
  const TournamentDetail({
    required this.id,
    required this.slug,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.hostId,
    required this.status,
    required this.isPublished,
    required this.categories,
    required this.venues,
    required this.playerCount,
    required this.pairCount,
    this.description,
    this.coverPhoto,
    this.youtubeVideoUrls = const [],
    this.contactName,
    this.contactEmail,
    this.contactPhone,
    this.host,
  });

  factory TournamentDetail.fromJson(Map<String, dynamic> json) {
    final categories = _maps(
      json['categories'],
    ).map(TournamentCategory.fromJson).toList(growable: false);
    final venues = _maps(
      json['tournamentVenues'],
    ).map(TournamentVenue.fromJson).toList(growable: false);
    final legacyVenue = _map(json['venue']);
    final resolvedVenues = venues.isNotEmpty
        ? venues
        : legacyVenue == null
        ? const <TournamentVenue>[]
        : [TournamentVenue.fromLegacyVenue(legacyVenue)];
    final counts = _map(json['_count']);
    final host = _map(json['host']);

    return TournamentDetail(
      id: _string(json['id']),
      slug: _nullableString(json['slug']) ?? _string(json['id']),
      name: _nullableString(json['name']) ?? '',
      description: _nullableString(json['description']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      hostId: _nullableString(json['hostId']) ?? '',
      status: TournamentStatus.fromWire(json['status'] as String?),
      isPublished: json['isPublished'] as bool? ?? false,
      coverPhoto: _nullableString(json['coverPhoto']),
      youtubeVideoUrls: _strings(json['youtubeVideoUrls']),
      contactName: _nullableString(json['contactName']),
      contactEmail: _nullableString(json['contactEmail']),
      contactPhone: _nullableString(json['contactPhone']),
      host: host == null ? null : TournamentHost.fromJson(host),
      categories: categories,
      venues: resolvedVenues,
      playerCount: _integer(counts?['players']),
      pairCount: _integer(counts?['pairs']),
    );
  }

  final String id;
  final String slug;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String hostId;
  final TournamentStatus status;
  final bool isPublished;
  final String? coverPhoto;
  final List<String> youtubeVideoUrls;
  final String? contactName;
  final String? contactEmail;
  final String? contactPhone;
  final TournamentHost? host;
  final List<TournamentCategory> categories;
  final List<TournamentVenue> venues;
  final int playerCount;
  final int pairCount;

  TournamentVenue? get primaryVenue {
    if (venues.isEmpty) return null;
    return venues.where((venue) => venue.isPrimary).firstOrNull ?? venues.first;
  }

  String? get resolvedCoverPhoto =>
      coverPhoto ??
      primaryVenue?.coverPhoto ??
      primaryVenue?.images.firstOrNull;

  int get registrationCount => categories.fold(
    0,
    (total, category) => total + category.registrationCount,
  );

  String? get resolvedContactName => contactName ?? host?.name;
  String? get resolvedContactEmail => contactEmail ?? host?.email;
}

class TournamentHost {
  const TournamentHost({
    required this.id,
    required this.name,
    required this.email,
    this.image,
  });

  factory TournamentHost.fromJson(Map<String, dynamic> json) => TournamentHost(
    id: _string(json['id']),
    name: _nullableString(json['name']) ?? '',
    email: _nullableString(json['email']) ?? '',
    image: _nullableString(json['image']),
  );

  final String id;
  final String name;
  final String email;
  final String? image;
}

class TournamentCategory {
  const TournamentCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.registrationMode,
    required this.format,
    required this.registrationCount,
    this.formatConfig = const {},
    this.winnersPerGroup,
    this.matchFormat,
    this.eliminationMatchFormat,
    this.thirdPlaceMatch,
  });

  factory TournamentCategory.fromJson(Map<String, dynamic> json) {
    final counts = _map(json['_count']);
    return TournamentCategory(
      id: _string(json['id']),
      name:
          _nullableString(json['name']) ?? _nullableString(json['type']) ?? '',
      type: _nullableString(json['type']) ?? '',
      registrationMode: TournamentRegistrationMode.fromWire(
        json['registrationMode'] as String?,
      ),
      format: TournamentCategoryFormat.fromWire(json['format'] as String?),
      registrationCount: _integer(counts?['registrations']),
      formatConfig: _map(json['formatConfig']) ?? const {},
      winnersPerGroup: _nullableInteger(json['winnersPerGroup']),
      matchFormat: _nullableString(json['matchFormat']),
      eliminationMatchFormat: _nullableString(json['eliminationMatchFormat']),
      thirdPlaceMatch: json['thirdPlaceMatch'] as bool?,
    );
  }

  final String id;
  final String name;
  final String type;
  final TournamentRegistrationMode registrationMode;
  final TournamentCategoryFormat format;
  final int registrationCount;
  final Map<String, dynamic> formatConfig;
  final int? winnersPerGroup;
  final String? matchFormat;
  final String? eliminationMatchFormat;
  final bool? thirdPlaceMatch;

  Map<String, dynamic> get roundRobinConfig {
    final nested = _map(formatConfig['roundRobin']);
    return nested ?? formatConfig;
  }

  String get pointsEarning =>
      _nullableString(roundRobinConfig['pointsEarning']) ?? 'match_results';
  int get winPoints => _nullableInteger(roundRobinConfig['winPoints']) ?? 2;
  int get lossPoints => _nullableInteger(roundRobinConfig['lossPoints']) ?? 1;
  int get tiePoints => _nullableInteger(roundRobinConfig['tiePoints']) ?? 0;
  List<Map<String, dynamic>> get tiebreakers {
    final configured = _maps(roundRobinConfig['tiebreakers']);
    if (configured.isNotEmpty) return configured;
    return const [
      {'id': 'total_points', 'label': 'totalPoints'},
      {'id': 'game_differential', 'label': 'gameDifferential'},
      {'id': 'total_wins', 'label': 'totalWins'},
      {'id': 'point_differential', 'label': 'pointDifferential'},
    ];
  }
}

class TournamentVenue {
  const TournamentVenue({
    required this.id,
    required this.name,
    this.isPrimary = false,
    this.acronym,
    this.placeId,
    this.address,
    this.district,
    this.city,
    this.lat,
    this.lng,
    this.coverPhoto,
    this.images = const [],
    this.isVerified = false,
  });

  factory TournamentVenue.fromJson(Map<String, dynamic> json) {
    final linked = _map(json['venue']);
    String? value(String key) =>
        _nullableString(json[key]) ?? _nullableString(linked?[key]);
    double? coordinate(String key) =>
        _double(json[key]) ?? _double(linked?[key]);
    return TournamentVenue(
      id: _nullableString(json['id']) ?? _nullableString(linked?['id']) ?? '',
      name: value('name') ?? value('address') ?? '',
      isPrimary: json['isPrimary'] as bool? ?? false,
      acronym: value('acronym'),
      placeId: value('placeId'),
      address: value('newAddress') ?? value('address'),
      district: value('newDistrict') ?? value('district'),
      city: value('newCity') ?? value('city'),
      lat: coordinate('lat'),
      lng: coordinate('lng'),
      coverPhoto: value('coverPhoto'),
      images: _strings(linked?['images'] ?? json['images']),
      isVerified: linked?['isVerified'] as bool? ?? false,
    );
  }

  factory TournamentVenue.fromLegacyVenue(Map<String, dynamic> json) =>
      TournamentVenue.fromJson({
        'id': json['id'],
        'isPrimary': true,
        'venue': json,
      });

  final String id;
  final String name;
  final bool isPrimary;
  final String? acronym;
  final String? placeId;
  final String? address;
  final String? district;
  final String? city;
  final double? lat;
  final double? lng;
  final String? coverPhoto;
  final List<String> images;
  final bool isVerified;

  String get addressLabel => [
    address,
    district,
    city,
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
}

class TournamentSponsor {
  const TournamentSponsor({
    required this.id,
    required this.name,
    this.logo,
    this.website,
    this.displayOrder = 0,
  });

  factory TournamentSponsor.fromJson(Map<String, dynamic> json) =>
      TournamentSponsor(
        id: _string(json['id']),
        name: _nullableString(json['name']) ?? '',
        logo: _nullableString(json['logo']),
        website: _nullableString(json['website']),
        displayOrder: _integer(json['displayOrder']),
      );

  final String id;
  final String name;
  final String? logo;
  final String? website;
  final int displayOrder;
}

class TournamentMatch {
  const TournamentMatch({
    required this.id,
    required this.categoryId,
    required this.round,
    required this.matchNumber,
    required this.status,
    required this.participants,
    this.groupId,
    this.startTime,
    this.score,
    this.sets = const [],
    this.winnerId,
    this.court,
    this.player1Score,
    this.player2Score,
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    final court = _map(json['court']);
    return TournamentMatch(
      id: _string(json['id']),
      categoryId: _string(json['categoryId']),
      groupId: _nullableString(json['groupId']),
      round: _nullableString(json['round']) ?? '',
      matchNumber: _integer(json['matchNumber']),
      status: TournamentMatchStatus.fromWire(json['status'] as String?),
      startTime: _nullableDate(json['startTime']),
      score: _nullableString(json['score']),
      sets: _maps(json['sets']).map(TournamentMatchSet.fromJson).toList(),
      winnerId: _nullableString(json['winnerId']),
      player1Score: _nullableInteger(json['player1Score']),
      player2Score: _nullableInteger(json['player2Score']),
      participants: _maps(
        json['participants'],
      ).map(TournamentMatchParticipant.fromJson).toList(),
      court: court == null ? null : TournamentCourt.fromJson(court),
    );
  }

  final String id;
  final String categoryId;
  final String? groupId;
  final String round;
  final int matchNumber;
  final TournamentMatchStatus status;
  final DateTime? startTime;
  final String? score;
  final List<TournamentMatchSet> sets;
  final String? winnerId;
  final List<TournamentMatchParticipant> participants;
  final TournamentCourt? court;
  final int? player1Score;
  final int? player2Score;

  TournamentRegistration? side(int position) => participants
      .where((participant) => participant.position == position)
      .firstOrNull
      ?.registration;

  int? get score1 =>
      player1Score ?? (sets.isEmpty ? null : sets.last.player1Score);
  int? get score2 =>
      player2Score ?? (sets.isEmpty ? null : sets.last.player2Score);
}

class TournamentMatchSet {
  const TournamentMatchSet({
    required this.player1Score,
    required this.player2Score,
  });

  factory TournamentMatchSet.fromJson(Map<String, dynamic> json) =>
      TournamentMatchSet(
        player1Score: _integer(json['player1Score']),
        player2Score: _integer(json['player2Score']),
      );

  final int player1Score;
  final int player2Score;
}

class TournamentCourt {
  const TournamentCourt({required this.number, this.name, this.venueName});

  factory TournamentCourt.fromJson(Map<String, dynamic> json) {
    final tournamentVenue = _map(json['tournamentVenue']);
    final linkedVenue = _map(tournamentVenue?['venue']);
    return TournamentCourt(
      number: _integer(json['courtNumber']),
      name: _nullableString(json['courtName']),
      venueName:
          _nullableString(tournamentVenue?['name']) ??
          _nullableString(linkedVenue?['name']),
    );
  }

  final int number;
  final String? name;
  final String? venueName;
}

class TournamentMatchParticipant {
  const TournamentMatchParticipant({
    required this.position,
    required this.registrationId,
    this.registration,
  });

  factory TournamentMatchParticipant.fromJson(Map<String, dynamic> json) {
    final registration = _map(json['categoryRegistration']);
    return TournamentMatchParticipant(
      position: _integer(json['position']),
      registrationId: _nullableString(json['categoryRegistrationId']) ?? '',
      registration: registration == null
          ? null
          : TournamentRegistration.fromJson(registration),
    );
  }

  final int position;
  final String registrationId;
  final TournamentRegistration? registration;
}

class TournamentRegistration {
  const TournamentRegistration({
    required this.id,
    this.player,
    this.pairName,
    this.pairMembers = const [],
  });

  factory TournamentRegistration.fromJson(Map<String, dynamic> json) {
    final pair = _map(json['pair']);
    final members = _maps(pair?['members'])
        .map((member) => _map(member['player']))
        .whereType<Map<String, dynamic>>()
        .map((player) => _nullableString(player['name']))
        .whereType<String>()
        .toList(growable: false);
    final player = _map(json['player']);
    return TournamentRegistration(
      id: _string(json['id']),
      player: player == null ? null : TournamentPlayer.fromJson(player),
      pairName: _nullableString(pair?['name']),
      pairMembers: members,
    );
  }

  final String id;
  final TournamentPlayer? player;
  final String? pairName;
  final List<String> pairMembers;

  String get teamLabel => player?.name ?? pairName ?? pairMembers.join(' / ');
  String get playerNames => player?.name ?? pairMembers.join(' / ');
}

class TournamentPlayer {
  const TournamentPlayer({required this.id, required this.name, this.image});

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) =>
      TournamentPlayer(
        id: _string(json['id']),
        name: _nullableString(json['name']) ?? '',
        image: _nullableString(json['image']),
      );

  final String id;
  final String name;
  final String? image;
}

class TournamentStandingGroup {
  const TournamentStandingGroup({required this.rows});

  factory TournamentStandingGroup.fromJson(Map<String, dynamic> json) =>
      TournamentStandingGroup(
        rows: _maps(
          json['standings'],
        ).map(TournamentStanding.fromJson).toList(growable: false),
      );

  final List<TournamentStanding> rows;
}

class TournamentStanding {
  const TournamentStanding({
    required this.registration,
    required this.matchesPlayed,
    required this.matchesWon,
    required this.matchesLost,
    required this.matchesDrawn,
    required this.matchesForfeited,
    required this.matchesCancelled,
    required this.points,
    required this.pointsFor,
    required this.pointDifference,
  });

  factory TournamentStanding.fromJson(Map<String, dynamic> json) =>
      TournamentStanding(
        registration: TournamentRegistration.fromJson(
          _map(json['registration']) ?? const {},
        ),
        matchesPlayed: _integer(json['matchesPlayed']),
        matchesWon: _integer(json['matchesWon']),
        matchesLost: _integer(json['matchesLost']),
        matchesDrawn: _integer(json['matchesDrawn']),
        matchesForfeited: _integer(json['matchesForfeited']),
        matchesCancelled: _integer(json['matchesCancelled']),
        points: _integer(json['points']),
        pointsFor: _integer(json['pointsFor']),
        pointDifference: _integer(json['pointDifference']),
      );

  final TournamentRegistration registration;
  final int matchesPlayed;
  final int matchesWon;
  final int matchesLost;
  final int matchesDrawn;
  final int matchesForfeited;
  final int matchesCancelled;
  final int points;
  final int pointsFor;
  final int pointDifference;

  bool get hasResult =>
      matchesPlayed > 0 ||
      matchesWon > 0 ||
      matchesLost > 0 ||
      matchesDrawn > 0 ||
      matchesForfeited > 0 ||
      matchesCancelled > 0 ||
      points != 0 ||
      pointsFor != 0 ||
      pointDifference != 0;
}

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value
          .whereType<Map<dynamic, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList()
    : const [];

String _string(dynamic value) => value?.toString() ?? '';

String? _nullableString(dynamic value) {
  final result = value?.toString().trim();
  return result == null || result.isEmpty ? null : result;
}

List<String> _strings(dynamic value) => value is List
    ? value.map(_nullableString).whereType<String>().toList(growable: false)
    : const [];

int _integer(dynamic value) => _nullableInteger(value) ?? 0;

int? _nullableInteger(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _double(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

DateTime _date(dynamic value) =>
    _nullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

DateTime? _nullableDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
