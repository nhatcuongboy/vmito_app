import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

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
    this.sportType = scoring.SportType.badminton,
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
      sportType: json['sportType'] == 'PICKLEBALL'
          ? scoring.SportType.pickleball
          : scoring.SportType.badminton,
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
  final scoring.SportType sportType;
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
    this.teamSize = 1,
    this.pointsToWin,
    this.winByTwo,
    this.pointCap,
    this.knockoutPointsToWin,
    this.knockoutWinByTwo,
    this.knockoutPointCap,
    this.finalPointsToWin,
    this.finalWinByTwo,
    this.finalPointCap,
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
      teamSize: _nullableInteger(json['teamSize']) ?? 1,
      pointsToWin: _nullableInteger(json['pointsToWin']),
      winByTwo: json['winByTwo'] as bool?,
      pointCap: _nullableInteger(json['pointCap']),
      knockoutPointsToWin: _nullableInteger(json['knockoutPointsToWin']),
      knockoutWinByTwo: json['knockoutWinByTwo'] as bool?,
      knockoutPointCap: _nullableInteger(json['knockoutPointCap']),
      finalPointsToWin: _nullableInteger(json['finalPointsToWin']),
      finalWinByTwo: json['finalWinByTwo'] as bool?,
      finalPointCap: _nullableInteger(json['finalPointCap']),
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
  final int teamSize;
  final int? pointsToWin;
  final bool? winByTwo;
  final int? pointCap;
  final int? knockoutPointsToWin;
  final bool? knockoutWinByTwo;
  final int? knockoutPointCap;
  final int? finalPointsToWin;
  final bool? finalWinByTwo;
  final int? finalPointCap;

  scoring.StageScoringCategory get scoringCategory =>
      scoring.StageScoringCategory(
        matchFormat: _matchFormat(matchFormat),
        pointsToWin: pointsToWin,
        winByTwo: winByTwo,
        pointCap: pointCap,
        knockoutPointsToWin: knockoutPointsToWin,
        knockoutWinByTwo: knockoutWinByTwo,
        knockoutPointCap: knockoutPointCap,
        finalPointsToWin: finalPointsToWin,
        finalWinByTwo: finalWinByTwo,
        finalPointCap: finalPointCap,
      );

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
    this.matchCode,
    this.endTime,
    this.estimatedEndTime,
    this.courtId,
    this.isDraw = false,
    this.isForfeit = false,
    this.player3Score,
    this.player4Score,
    this.player1Points,
    this.player2Points,
    this.matchFormat,
    this.pointsToWin,
    this.winByTwo,
    this.pointCap,
    this.notes,
    this.refereeId,
    this.referee,
    this.refereeName,
    this.bracketType,
    this.winnerNextMatchId,
    this.winnerNextSlot,
    this.loserNextMatchId,
    this.loserNextSlot,
    this.updatedAt,
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    final court = _map(json['court']);
    final referee = _map(json['referee']);
    return TournamentMatch(
      id: _string(json['id']),
      categoryId: _string(json['categoryId']),
      groupId: _nullableString(json['groupId']),
      round: _nullableString(json['round']) ?? '',
      matchNumber: _integer(json['matchNumber']),
      status: TournamentMatchStatus.fromWire(json['status'] as String?),
      startTime: _nullableDate(json['startTime']),
      endTime: _nullableDate(json['endTime']),
      estimatedEndTime: _nullableDate(json['estimatedEndTime']),
      matchCode: _nullableString(json['matchCode']),
      courtId:
          _nullableString(json['courtId']) ?? _nullableString(court?['id']),
      score: _nullableString(json['score']),
      sets: _maps(json['sets']).map(TournamentMatchSet.fromJson).toList(),
      winnerId: _nullableString(json['winnerId']),
      player1Score: _nullableInteger(json['player1Score']),
      player2Score: _nullableInteger(json['player2Score']),
      player3Score: _nullableInteger(json['player3Score']),
      player4Score: _nullableInteger(json['player4Score']),
      player1Points: _nullableInteger(json['player1Points']),
      player2Points: _nullableInteger(json['player2Points']),
      isDraw: json['isDraw'] as bool? ?? false,
      isForfeit: json['isForfeit'] as bool? ?? false,
      matchFormat: _nullableString(json['matchFormat']),
      pointsToWin: _nullableInteger(json['pointsToWin']),
      winByTwo: json['winByTwo'] as bool?,
      pointCap: _nullableInteger(json['pointCap']),
      notes: _nullableString(json['notes']),
      refereeId:
          _nullableString(json['refereeId']) ?? _nullableString(referee?['id']),
      referee: referee == null ? null : TournamentUmpire.fromJson(referee),
      refereeName: _nullableString(json['refereeName']),
      bracketType: _nullableString(json['bracketType']),
      winnerNextMatchId: _nullableString(json['winnerNextMatchId']),
      winnerNextSlot: _nullableInteger(json['winnerNextSlot']),
      loserNextMatchId: _nullableString(json['loserNextMatchId']),
      loserNextSlot: _nullableInteger(json['loserNextSlot']),
      updatedAt: _nullableDate(json['updatedAt']),
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
  final DateTime? endTime;
  final DateTime? estimatedEndTime;
  final String? matchCode;
  final String? courtId;
  final String? score;
  final List<TournamentMatchSet> sets;
  final String? winnerId;
  final List<TournamentMatchParticipant> participants;
  final TournamentCourt? court;
  final int? player1Score;
  final int? player2Score;
  final int? player3Score;
  final int? player4Score;
  final int? player1Points;
  final int? player2Points;
  final bool isDraw;
  final bool isForfeit;
  final String? matchFormat;
  final int? pointsToWin;
  final bool? winByTwo;
  final int? pointCap;
  final String? notes;
  final String? refereeId;
  final TournamentUmpire? referee;
  final String? refereeName;
  final String? bracketType;
  final String? winnerNextMatchId;
  final int? winnerNextSlot;
  final String? loserNextMatchId;
  final int? loserNextSlot;
  final DateTime? updatedAt;

  TournamentRegistration? side(int position) => participants
      .where((participant) => participant.position == position)
      .firstOrNull
      ?.registration;

  int? get score1 =>
      player1Score ?? (sets.isEmpty ? null : sets.last.player1Score);
  int? get score2 =>
      player2Score ?? (sets.isEmpty ? null : sets.last.player2Score);

  bool get participantsResolved => side(1) != null && side(2) != null;

  scoring.ScoringMatch scoringMatch(TournamentCategory? category) =>
      scoring.ScoringMatch(
        matchFormat: _matchFormat(matchFormat),
        pointsToWin: pointsToWin,
        winByTwo: winByTwo,
        pointCap: pointCap,
        round: round,
        category: category?.scoringCategory,
      );

  TournamentMatch copyWith({
    TournamentMatchStatus? status,
    DateTime? startTime,
    bool clearStartTime = false,
    DateTime? endTime,
    bool clearEndTime = false,
    DateTime? estimatedEndTime,
    bool clearEstimatedEndTime = false,
    String? matchCode,
    String? courtId,
    bool clearCourt = false,
    String? score,
    List<TournamentMatchSet>? sets,
    String? winnerId,
    bool clearWinner = false,
    bool? isDraw,
    bool? isForfeit,
    TournamentCourt? court,
    int? player1Score,
    int? player2Score,
    int? player1Points,
    int? player2Points,
    String? refereeId,
    bool clearReferee = false,
    TournamentUmpire? referee,
    String? refereeName,
    DateTime? updatedAt,
  }) => TournamentMatch(
    id: id,
    categoryId: categoryId,
    groupId: groupId,
    round: round,
    matchNumber: matchNumber,
    status: status ?? this.status,
    participants: participants,
    startTime: clearStartTime ? null : startTime ?? this.startTime,
    endTime: clearEndTime ? null : endTime ?? this.endTime,
    estimatedEndTime: clearEstimatedEndTime
        ? null
        : estimatedEndTime ?? this.estimatedEndTime,
    matchCode: matchCode ?? this.matchCode,
    courtId: clearCourt ? null : courtId ?? this.courtId,
    score: score ?? this.score,
    sets: sets ?? this.sets,
    winnerId: clearWinner ? null : winnerId ?? this.winnerId,
    court: clearCourt ? null : court ?? this.court,
    player1Score: player1Score ?? this.player1Score,
    player2Score: player2Score ?? this.player2Score,
    player3Score: player3Score,
    player4Score: player4Score,
    player1Points: player1Points ?? this.player1Points,
    player2Points: player2Points ?? this.player2Points,
    isDraw: isDraw ?? this.isDraw,
    isForfeit: isForfeit ?? this.isForfeit,
    matchFormat: matchFormat,
    pointsToWin: pointsToWin,
    winByTwo: winByTwo,
    pointCap: pointCap,
    notes: notes,
    refereeId: clearReferee ? null : refereeId ?? this.refereeId,
    referee: clearReferee ? null : referee ?? this.referee,
    refereeName: refereeName ?? this.refereeName,
    bracketType: bracketType,
    winnerNextMatchId: winnerNextMatchId,
    winnerNextSlot: winnerNextSlot,
    loserNextMatchId: loserNextMatchId,
    loserNextSlot: loserNextSlot,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

class TournamentMatchSet {
  const TournamentMatchSet({
    this.setNumber = 1,
    required this.player1Score,
    required this.player2Score,
    this.player3Score,
    this.player4Score,
  });

  factory TournamentMatchSet.fromJson(Map<String, dynamic> json) =>
      TournamentMatchSet(
        setNumber: _nullableInteger(json['setNumber']) ?? 1,
        player1Score: _integer(json['player1Score']),
        player2Score: _integer(json['player2Score']),
        player3Score: _nullableInteger(json['player3Score']),
        player4Score: _nullableInteger(json['player4Score']),
      );

  final int setNumber;
  final int player1Score;
  final int player2Score;
  final int? player3Score;
  final int? player4Score;

  scoring.MatchSet get scoringSet => scoring.MatchSet(
    setNumber: setNumber,
    player1Score: player1Score,
    player2Score: player2Score,
    player3Score: player3Score,
    player4Score: player4Score,
  );
}

class TournamentCourt {
  const TournamentCourt({
    required this.number,
    this.id = '',
    this.tournamentId,
    this.tournamentVenueId,
    this.name,
    this.venueName,
    this.notes,
  });

  factory TournamentCourt.fromJson(Map<String, dynamic> json) {
    final tournamentVenue = _map(json['tournamentVenue']);
    final linkedVenue = _map(tournamentVenue?['venue']);
    return TournamentCourt(
      id: _nullableString(json['id']) ?? '',
      tournamentId: _nullableString(json['tournamentId']),
      tournamentVenueId: _nullableString(json['tournamentVenueId']),
      number: _integer(json['courtNumber']),
      name: _nullableString(json['courtName']),
      notes: _nullableString(json['notes']),
      venueName:
          _nullableString(tournamentVenue?['name']) ??
          _nullableString(linkedVenue?['name']),
    );
  }

  final int number;
  final String id;
  final String? tournamentId;
  final String? tournamentVenueId;
  final String? name;
  final String? venueName;
  final String? notes;

  String label(String courtLabel) =>
      name?.trim().isNotEmpty ?? false ? name! : '$courtLabel $number';
}

class TournamentUmpire {
  const TournamentUmpire({
    required this.id,
    required this.name,
    this.tournamentId,
    this.email,
    this.phone,
    this.notes,
    this.userId,
  });

  factory TournamentUmpire.fromJson(Map<String, dynamic> json) =>
      TournamentUmpire(
        id: _string(json['id']),
        name: _nullableString(json['name']) ?? '',
        tournamentId: _nullableString(json['tournamentId']),
        email: _nullableString(json['email']),
        phone: _nullableString(json['phone']),
        notes: _nullableString(json['notes']),
        userId:
            _nullableString(json['userId']) ??
            _nullableString(_map(json['user'])?['id']),
      );

  final String id;
  final String name;
  final String? tournamentId;
  final String? email;
  final String? phone;
  final String? notes;
  final String? userId;
}

class TournamentCategoryGroup {
  const TournamentCategoryGroup({
    required this.id,
    required this.categoryId,
    required this.number,
    this.name,
  });

  factory TournamentCategoryGroup.fromJson(Map<String, dynamic> json) =>
      TournamentCategoryGroup(
        id: _string(json['id']),
        categoryId: _string(json['categoryId']),
        number: _integer(json['groupNumber']),
        name: _nullableString(json['name']),
      );

  final String id;
  final String categoryId;
  final int number;
  final String? name;
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
      registrationId:
          _nullableString(json['categoryRegistrationId']) ??
          _nullableString(registration?['id']) ??
          '',
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

scoring.MatchFormat? _matchFormat(String? value) => switch (value) {
  'BEST_OF_1' => scoring.MatchFormat.bestOf1,
  'BEST_OF_3' => scoring.MatchFormat.bestOf3,
  'BEST_OF_5' => scoring.MatchFormat.bestOf5,
  _ => null,
};
