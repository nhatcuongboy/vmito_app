import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

enum TournamentScheduleViewMode { list, calendar }

enum TournamentScheduleStatusFilter {
  upcoming,
  finished,
  cancelled,
  forfeited,
}

class TournamentScheduleFilters {
  const TournamentScheduleFilters({
    this.query = '',
    this.categoryIds = const {},
    this.rounds = const {},
    this.courtIds = const {},
    this.statuses = const {},
    this.teamIds = const {},
    this.dateFrom,
    this.dateTo,
    this.refereeOnly = false,
  });

  final String query;
  final Set<String> categoryIds;
  final Set<String> rounds;
  final Set<String> courtIds;
  final Set<TournamentScheduleStatusFilter> statuses;
  final Set<String> teamIds;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final bool refereeOnly;

  int get activeCount =>
      categoryIds.length +
      rounds.length +
      courtIds.length +
      statuses.length +
      teamIds.length +
      (dateFrom == null ? 0 : 1) +
      (dateTo == null ? 0 : 1) +
      (query.trim().isEmpty ? 0 : 1);

  TournamentScheduleFilters copyWith({
    String? query,
    Set<String>? categoryIds,
    Set<String>? rounds,
    Set<String>? courtIds,
    Set<TournamentScheduleStatusFilter>? statuses,
    Set<String>? teamIds,
    DateTime? dateFrom,
    bool clearDateFrom = false,
    DateTime? dateTo,
    bool clearDateTo = false,
    bool? refereeOnly,
  }) => TournamentScheduleFilters(
    query: query ?? this.query,
    categoryIds: categoryIds ?? this.categoryIds,
    rounds: rounds ?? this.rounds,
    courtIds: courtIds ?? this.courtIds,
    statuses: statuses ?? this.statuses,
    teamIds: teamIds ?? this.teamIds,
    dateFrom: clearDateFrom ? null : dateFrom ?? this.dateFrom,
    dateTo: clearDateTo ? null : dateTo ?? this.dateTo,
    refereeOnly: refereeOnly ?? this.refereeOnly,
  );
}

List<TournamentMatch> filterAndSortTournamentMatches(
  Iterable<TournamentMatch> matches,
  TournamentScheduleFilters filters, {
  String? currentUserId,
  bool canRefereeAny = false,
  Set<String> ownAssignmentIds = const {},
}) {
  final query = normalizeTournamentSearch(filters.query);
  final filtered = matches
      .where((match) {
        if (query.isNotEmpty && !_matchSearchText(match).contains(query)) {
          return false;
        }
        if (filters.refereeOnly) {
          if (ownAssignmentIds.isNotEmpty) {
            if (!ownAssignmentIds.contains(match.id)) return false;
          } else if (!canRefereeAny &&
              (currentUserId == null ||
                  match.referee?.userId != currentUserId)) {
            return false;
          }
        }
        if (filters.categoryIds.isNotEmpty &&
            !filters.categoryIds.contains(match.categoryId)) {
          return false;
        }
        if (filters.rounds.isNotEmpty &&
            !filters.rounds.contains(match.round)) {
          return false;
        }
        if (filters.courtIds.isNotEmpty &&
            !filters.courtIds.contains(match.courtId)) {
          return false;
        }
        if (filters.statuses.isNotEmpty &&
            !filters.statuses.any((status) => _matchesStatus(match, status))) {
          return false;
        }
        if (filters.teamIds.isNotEmpty &&
            !match.participants.any(
              (participant) =>
                  filters.teamIds.contains(participant.registrationId),
            )) {
          return false;
        }
        final start = match.startTime;
        if ((filters.dateFrom != null || filters.dateTo != null) &&
            start == null) {
          return false;
        }
        if (start != null) {
          final localStart = start.toLocal();
          final day = DateTime(
            localStart.year,
            localStart.month,
            localStart.day,
          );
          if (filters.dateFrom case final from? when day.isBefore(_day(from))) {
            return false;
          }
          if (filters.dateTo case final to? when day.isAfter(_day(to))) {
            return false;
          }
        }
        return true;
      })
      .toList(growable: false);

  return [...filtered]..sort((first, second) {
    final firstTime = first.startTime;
    final secondTime = second.startTime;
    if (firstTime != null && secondTime != null) {
      final result = firstTime.compareTo(secondTime);
      return result != 0
          ? result
          : first.matchNumber.compareTo(second.matchNumber);
    }
    if (firstTime != null) return -1;
    if (secondTime != null) return 1;
    return first.matchNumber.compareTo(second.matchNumber);
  });
}

String tournamentMatchSideLabel(
  TournamentMatch match,
  int position, {
  required Iterable<TournamentMatch> allMatches,
  required String toBeDetermined,
  required String Function(int matchNumber) winnerOfMatch,
  required String Function(int matchNumber) loserOfMatch,
  bool showPlayerNames = false,
}) {
  final registration = match.side(position);
  if (registration != null) {
    final label = showPlayerNames
        ? registration.playerNames
        : registration.teamLabel;
    if (label.trim().isNotEmpty) return label;
  }

  for (final feeder in allMatches) {
    if (feeder.winnerNextMatchId == match.id &&
        feeder.winnerNextSlot == position) {
      return winnerOfMatch(feeder.matchNumber);
    }
    if (feeder.loserNextMatchId == match.id &&
        feeder.loserNextSlot == position) {
      return loserOfMatch(feeder.matchNumber);
    }
  }
  if (_conventionalFeeder(match, position, allMatches) case (
    matchNumber: final number,
    :final loser,
  )) {
    return loser ? loserOfMatch(number) : winnerOfMatch(number);
  }
  return toBeDetermined;
}

({int matchNumber, bool loser})? _conventionalFeeder(
  TournamentMatch match,
  int position,
  Iterable<TournamentMatch> allMatches,
) {
  const roundOrder = ['R128', 'R64', 'R32', 'R16', 'QF', 'SF', 'F'];
  final byRound = <String, List<TournamentMatch>>{};
  for (final candidate in allMatches) {
    if (candidate.categoryId != match.categoryId ||
        candidate.groupId != null ||
        candidate.round.toUpperCase() == 'GROUP') {
      continue;
    }
    byRound.putIfAbsent(candidate.round.toUpperCase(), () => []).add(candidate);
  }
  for (final matches in byRound.values) {
    matches.sort(
      (first, second) => first.matchNumber.compareTo(second.matchNumber),
    );
  }
  final round = match.round.toUpperCase();
  if (round == '3RD') {
    final semifinals = byRound['SF'];
    if (semifinals == null || position > semifinals.length) return null;
    return (matchNumber: semifinals[position - 1].matchNumber, loser: true);
  }
  final activeRounds = [
    for (final item in roundOrder)
      if (byRound.containsKey(item)) item,
  ];
  final roundIndex = activeRounds.indexOf(round);
  if (roundIndex <= 0) return null;
  final currentRound = byRound[round]!;
  final slotIndex = currentRound.indexWhere((item) => item.id == match.id);
  if (slotIndex < 0) return null;
  final previous = byRound[activeRounds[roundIndex - 1]]!;
  final feederIndex = slotIndex * 2 + position - 1;
  if (feederIndex >= previous.length) return null;
  return (matchNumber: previous[feederIndex].matchNumber, loser: false);
}

bool tournamentCategoryReadyForBracket(
  TournamentCategory category,
  Iterable<TournamentMatch> allMatches,
) {
  if (category.format !=
      TournamentCategoryFormat.roundRobinToSingleElimination) {
    return false;
  }
  final matches = allMatches
      .where((match) => match.categoryId == category.id)
      .toList(growable: false);
  final groups = matches
      .where((match) => match.groupId != null || match.round == 'GROUP')
      .toList(growable: false);
  if (groups.isEmpty ||
      groups.any((match) => match.status != TournamentMatchStatus.finished)) {
    return false;
  }
  return !matches.any(
    (match) =>
        match.groupId == null &&
        match.round != 'GROUP' &&
        match.participants.isNotEmpty,
  );
}

TournamentMatch mergeTournamentRealtimeMatch(
  TournamentMatch current,
  Map<String, dynamic> incoming,
) {
  final rawSets = incoming['sets'];
  final sets = rawSets is List
      ? rawSets
            .whereType<Map<dynamic, dynamic>>()
            .map((item) => TournamentMatchSet.fromJson(Map.from(item)))
            .toList(growable: true)
      : <TournamentMatchSet>[];
  final currentSet = incoming['currentSet'];
  if (currentSet is Map) {
    final normalized = Map<String, dynamic>.from(currentSet);
    final number = _int(normalized['setNumber']);
    sets
      ..removeWhere((set) => set.setNumber == number)
      ..add(
        TournamentMatchSet(
          setNumber: number,
          player1Score: _int(normalized['side1']),
          player2Score: _int(normalized['side2']),
        ),
      )
      ..sort((first, second) => first.setNumber.compareTo(second.setNumber));
  }
  final totals = sets.fold(
    (first: 0, second: 0),
    (total, set) => (
      first: total.first + set.player1Score,
      second: total.second + set.player2Score,
    ),
  );
  final rawCourt = incoming['court'];
  final court = rawCourt is Map
      ? TournamentCourt.fromJson(Map<String, dynamic>.from(rawCourt))
      : current.court;
  final winnerId = _string(incoming['winnerId']);
  return current.copyWith(
    status: TournamentMatchStatus.fromWire(_string(incoming['status'])),
    startTime: _date(incoming['startTime']),
    clearStartTime:
        incoming.containsKey('startTime') && incoming['startTime'] == null,
    endTime: _date(incoming['endTime']),
    clearEndTime:
        incoming.containsKey('endTime') && incoming['endTime'] == null,
    estimatedEndTime: _date(incoming['estimatedEndTime']),
    clearEstimatedEndTime:
        incoming.containsKey('estimatedEndTime') &&
        incoming['estimatedEndTime'] == null,
    courtId: court?.id,
    court: court,
    score: _string(incoming['score']),
    sets: sets.isEmpty ? current.sets : sets,
    winnerId: winnerId,
    clearWinner: incoming.containsKey('winnerId') && winnerId == null,
    isDraw: incoming['isDraw'] as bool?,
    player1Score: sets.isEmpty ? current.player1Score : totals.first,
    player2Score: sets.isEmpty ? current.player2Score : totals.second,
    refereeName: _string(incoming['refereeName']),
    updatedAt: _date(incoming['updatedAt']),
  );
}

class TournamentScheduleUpdateDraft {
  const TournamentScheduleUpdateDraft({
    required this.matchId,
    required this.matchCode,
    this.courtId,
    this.startTime,
    this.endTime,
    this.refereeId,
  });

  final String matchId;
  final String matchCode;
  final String? courtId;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? refereeId;
}

class TournamentResultDraft {
  const TournamentResultDraft({
    required this.score,
    this.sets = const [],
    this.includeSets = false,
    this.winnerId,
    this.isDraw,
    this.isForfeit,
    this.player1Points,
    this.player2Points,
    this.player1Score,
    this.player2Score,
    this.player3Score,
    this.player4Score,
  });

  final String score;
  final List<TournamentMatchSet> sets;
  final bool includeSets;
  final String? winnerId;
  final bool? isDraw;
  final bool? isForfeit;
  final int? player1Points;
  final int? player2Points;
  final int? player1Score;
  final int? player2Score;
  final int? player3Score;
  final int? player4Score;

  Map<String, dynamic> toJson() => {
    'score': score,
    if (includeSets)
      'sets': [
        for (final set in sets)
          {
            'setNumber': set.setNumber,
            'player1Score': set.player1Score,
            'player2Score': set.player2Score,
            if (set.player3Score != null) 'player3Score': set.player3Score,
            if (set.player4Score != null) 'player4Score': set.player4Score,
          },
      ],
    if (winnerId != null) 'winnerId': winnerId,
    if (isDraw != null) 'isDraw': isDraw,
    if (isForfeit != null) 'isForfeit': isForfeit,
    if (player1Points != null) 'player1Points': player1Points,
    if (player2Points != null) 'player2Points': player2Points,
    if (player1Score != null) 'player1Score': player1Score,
    if (player2Score != null) 'player2Score': player2Score,
    if (player3Score != null) 'player3Score': player3Score,
    if (player4Score != null) 'player4Score': player4Score,
  };
}

String normalizeTournamentSearch(String value) {
  const source =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ'
      'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ';
  const target =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
      'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';
  final buffer = StringBuffer();
  for (final code in value.runes) {
    final character = String.fromCharCode(code);
    final index = source.indexOf(character);
    buffer.write(index < 0 ? character : target[index]);
  }
  return buffer.toString().toLowerCase().trim();
}

bool _matchesStatus(
  TournamentMatch match,
  TournamentScheduleStatusFilter status,
) => switch (status) {
  TournamentScheduleStatusFilter.forfeited => match.isForfeit,
  TournamentScheduleStatusFilter.cancelled =>
    match.status == TournamentMatchStatus.cancelled,
  TournamentScheduleStatusFilter.finished =>
    match.status == TournamentMatchStatus.finished && !match.isForfeit,
  TournamentScheduleStatusFilter.upcoming =>
    match.status == TournamentMatchStatus.scheduled ||
        match.status == TournamentMatchStatus.inProgress,
};

String _matchSearchText(TournamentMatch match) => normalizeTournamentSearch(
  [
    match.matchCode,
    '#${match.matchNumber}',
    for (final participant in match.participants) ...[
      participant.registration?.teamLabel,
      participant.registration?.playerNames,
    ],
  ].whereType<String>().join(' '),
);

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

String? _string(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(dynamic value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

DateTime? _date(dynamic value) => switch (value) {
  final DateTime date => date,
  final String text => DateTime.tryParse(text),
  _ => null,
};
