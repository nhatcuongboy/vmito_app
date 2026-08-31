import 'dart:math' as math;

import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

enum TournamentStandingsStage { pool, playoffs }

enum TournamentStandingsView { pools, overall }

class TournamentOverallStanding {
  const TournamentOverallStanding({
    required this.standing,
    required this.group,
    required this.rank,
  });

  final TournamentStanding standing;
  final TournamentCategoryGroup? group;
  final int rank;
}

int compareTournamentStandings(
  TournamentStanding first,
  TournamentStanding second,
) => second.points.compareTo(first.points) != 0
    ? second.points.compareTo(first.points)
    : second.pointDifference.compareTo(first.pointDifference) != 0
    ? second.pointDifference.compareTo(first.pointDifference)
    : second.pointsFor.compareTo(first.pointsFor) != 0
    ? second.pointsFor.compareTo(first.pointsFor)
    : second.matchesWon.compareTo(first.matchesWon) != 0
    ? second.matchesWon.compareTo(first.matchesWon)
    : second.matchesPlayed.compareTo(first.matchesPlayed);

List<TournamentOverallStanding> buildTournamentOverallStandings(
  List<TournamentStandingGroup> groups,
) {
  final entries =
      [
        for (final group in groups)
          for (final standing in group.rows)
            (standing: standing, group: group.group),
      ]..sort(
        (first, second) =>
            compareTournamentStandings(first.standing, second.standing),
      );
  return [
    for (var index = 0; index < entries.length; index++)
      TournamentOverallStanding(
        standing: entries[index].standing,
        group: entries[index].group,
        rank: index + 1,
      ),
  ];
}

bool tournamentGroupStageComplete(
  String categoryId,
  List<TournamentMatch> matches,
) {
  final groupMatches = matches.where(
    (match) =>
        match.categoryId == categoryId &&
        (match.groupId != null || match.round.toUpperCase() == 'GROUP'),
  );
  return groupMatches.isNotEmpty &&
      groupMatches.every(
        (match) => match.status == TournamentMatchStatus.finished,
      );
}

class TournamentRoundRobinItem {
  const TournamentRoundRobinItem({
    required this.id,
    required this.label,
    this.description = '',
    this.abbreviation = '',
    this.required = false,
  });

  factory TournamentRoundRobinItem.fromJson(Map<String, dynamic> json) =>
      TournamentRoundRobinItem(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        abbreviation: json['abbreviation']?.toString() ?? '',
        required: json['required'] as bool? ?? false,
      );

  final String id;
  final String label;
  final String description;
  final String abbreviation;
  final bool required;
}

class TournamentRoundRobinConfig {
  const TournamentRoundRobinConfig({
    required this.pointsEarning,
    required this.winPoints,
    required this.tiePoints,
    required this.lossPoints,
    required this.cancelledMatchPoints,
    required this.gameWinPoints,
    required this.gameLossPoints,
    required this.forfeitWinPoints,
    required this.forfeitLossPoints,
    required this.tiebreakers,
    required this.statistics,
    required this.standingsColumns,
  });

  factory TournamentRoundRobinConfig.fromCategory(
    TournamentCategory category,
  ) {
    final config = category.roundRobinConfig;
    int value(String key, int fallback) => switch (config[key]) {
      final int number => number,
      final num number => number.toInt(),
      final String number => int.tryParse(number) ?? fallback,
      _ => fallback,
    };
    List<TournamentRoundRobinItem> items(
      String key,
      List<TournamentRoundRobinItem> fallback,
    ) {
      final raw = config[key];
      if (raw is! List || raw.isEmpty) return fallback;
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (item) => TournamentRoundRobinItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }

    return TournamentRoundRobinConfig(
      pointsEarning: config['pointsEarning']?.toString() ?? 'match_results',
      winPoints: value('winPoints', 2),
      tiePoints: value('tiePoints', 0),
      lossPoints: value('lossPoints', 1),
      cancelledMatchPoints: value('cancelledMatchPoints', 0),
      gameWinPoints: value('gameWinPoints', 0),
      gameLossPoints: value('gameLossPoints', 0),
      forfeitWinPoints: value('forfeitWinPoints', 0),
      forfeitLossPoints: value('forfeitLossPoints', 0),
      tiebreakers: items('tiebreakers', _defaultTiebreakers),
      statistics: items('statistics', _defaultStatistics),
      standingsColumns: items('standingsColumns', _defaultStandingsColumns),
    );
  }

  final String pointsEarning;
  final int winPoints;
  final int tiePoints;
  final int lossPoints;
  final int cancelledMatchPoints;
  final int gameWinPoints;
  final int gameLossPoints;
  final int forfeitWinPoints;
  final int forfeitLossPoints;
  final List<TournamentRoundRobinItem> tiebreakers;
  final List<TournamentRoundRobinItem> statistics;
  final List<TournamentRoundRobinItem> standingsColumns;
}

const _defaultTiebreakers = [
  TournamentRoundRobinItem(
    id: 'total_points',
    label: 'totalPoints',
    description: 'totalPointsDesc',
  ),
  TournamentRoundRobinItem(
    id: 'game_differential',
    label: 'gameDifferential',
    description: 'gameDifferentialDesc',
  ),
  TournamentRoundRobinItem(
    id: 'total_wins',
    label: 'totalWins',
    description: 'totalWinsDesc',
  ),
  TournamentRoundRobinItem(
    id: 'point_differential',
    label: 'pointDifferential',
    description: 'pointDifferentialDesc',
  ),
];

const _defaultStatistics = [
  TournamentRoundRobinItem(
    id: 'points',
    label: 'points',
    abbreviation: 'P',
    required: true,
  ),
];

const _defaultStandingsColumns = [
  TournamentRoundRobinItem(
    id: 'matches_played',
    label: 'matchesPlayed',
    abbreviation: 'MP',
  ),
  TournamentRoundRobinItem(id: 'wins', label: 'wins', abbreviation: 'W'),
  TournamentRoundRobinItem(id: 'ties', label: 'ties', abbreviation: 'T'),
  TournamentRoundRobinItem(id: 'losses', label: 'losses', abbreviation: 'L'),
  TournamentRoundRobinItem(
    id: 'points_differential',
    label: 'pointsDifferential',
    abbreviation: '+/-',
  ),
];

class TournamentBracketLabels {
  const TournamentBracketLabels({
    required this.winnerOf,
    required this.loserOf,
    required this.poolSeed,
    required this.ordinal,
    required this.bye,
    required this.tbd,
  });

  final String Function(int matchNumber) winnerOf;
  final String Function(int matchNumber) loserOf;
  final String Function(String rank, String pool) poolSeed;
  final String Function(int zeroBasedRank) ordinal;
  final String bye;
  final String tbd;
}

class TournamentBracketMatch {
  const TournamentBracketMatch({
    required this.id,
    required this.round,
    required this.matchNumber,
    required this.status,
    required this.side1Label,
    required this.side2Label,
    required this.isFinished,
    this.score,
    this.winnerPosition,
    this.isReset = false,
  });

  final String id;
  final String round;
  final int matchNumber;
  final TournamentMatchStatus status;
  final String side1Label;
  final String side2Label;
  final bool isFinished;
  final String? score;
  final int? winnerPosition;
  final bool isReset;
}

class TournamentBracketColumn {
  const TournamentBracketColumn({required this.round, required this.matches});

  final String round;
  final List<TournamentBracketMatch> matches;
}

const tournamentBracketRoundOrder = [
  'R128',
  'R64',
  'R32',
  'R16',
  'QF',
  'SF',
  'F',
];
const tournamentThirdPlaceRound = '3RD';
const _poolLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

int nextTournamentPowerOfTwo(int value) {
  var power = 1;
  while (power < value) {
    power *= 2;
  }
  return power;
}

String tournamentBracketRoundCode(int roundIndex, int totalRounds) {
  final fromFinal = totalRounds - 1 - roundIndex;
  if (fromFinal == 0) return 'F';
  if (fromFinal == 1) return 'SF';
  if (fromFinal == 2) return 'QF';
  return 'R${math.pow(2, fromFinal + 1).toInt()}';
}

List<int> generateTournamentStandardSeeding(int bracketSize) {
  if (bracketSize == 1) return const [1];
  final half = generateTournamentStandardSeeding(bracketSize ~/ 2);
  return [
    for (final seed in half) ...[seed, bracketSize + 1 - seed],
  ];
}

List<String> _advancingSlots(
  int groupCount,
  int winnersPerGroup,
  TournamentBracketLabels labels,
) => [
  for (var rank = 0; rank < winnersPerGroup; rank++)
    for (var group = 0; group < groupCount; group++)
      labels.poolSeed(
        labels.ordinal(rank),
        group < _poolLabels.length ? _poolLabels[group] : '${group + 1}',
      ),
];

List<String> resolveTournamentBracketSlots(
  TournamentCategory category,
  int groupCount,
  int winnersPerGroup,
  TournamentBracketLabels labels,
) {
  final advancing = _advancingSlots(groupCount, winnersPerGroup, labels);
  if (advancing.length < 2) return const [];
  final bracketSize = nextTournamentPowerOfTwo(advancing.length);
  final order = generateTournamentStandardSeeding(bracketSize);
  final defaults = [
    for (final seed in order)
      seed <= advancing.length ? advancing[seed - 1] : '',
  ];
  final config = category.formatConfig;
  final nested = category.format == TournamentCategoryFormat.singleElimination
      ? config['singleElimination']
      : config['playoffs'];
  final raw = nested is Map ? nested['seedOrder'] : null;
  final custom = raw is List
      ? raw.map((value) => value.toString()).toList()
      : null;
  if (custom == null || custom.isEmpty) return defaults;
  if (category.format == TournamentCategoryFormat.singleElimination) {
    return custom;
  }
  final valid = advancing.toSet();
  return custom.length == defaults.length &&
          custom.every((slot) => slot.isEmpty || valid.contains(slot))
      ? custom
      : defaults;
}

List<TournamentBracketMatch> buildTournamentEliminationMatches({
  required TournamentCategory category,
  required List<TournamentMatch> matches,
  required TournamentBracketLabels labels,
  bool showPlayerNames = false,
  int groupStageMatchCount = 0,
}) {
  if (matches.isNotEmpty) {
    return [
      for (final match in matches)
        _toBracketMatch(
          match,
          matches,
          category,
          labels,
          showPlayerNames: showPlayerNames,
        ),
    ];
  }
  final single = category.format == TournamentCategoryFormat.singleElimination;
  final groupCount = single ? 1 : category.groupCount;
  final winners = single
      ? category.registrationCount
      : category.winnersPerGroup ?? 0;
  final teamCount = groupCount * winners;
  final bracketSize = nextTournamentPowerOfTwo(teamCount);
  if (bracketSize < 2) return const [];
  final totalRounds = math.log(bracketSize) ~/ math.ln2;
  final roundNumbers = <List<int>>[];
  var number = single ? 1 : groupStageMatchCount + 1;
  for (var round = 0; round < totalRounds; round++) {
    roundNumbers.add([
      for (
        var index = 0;
        index < bracketSize ~/ math.pow(2, round + 1);
        index++
      )
        number++,
    ]);
  }
  final slots = resolveTournamentBracketSlots(
    category,
    groupCount,
    winners,
    labels,
  );
  final result = <TournamentBracketMatch>[];
  for (var round = 0; round < totalRounds; round++) {
    for (var index = 0; index < roundNumbers[round].length; index++) {
      final previous = round == 0 ? const <int>[] : roundNumbers[round - 1];
      result.add(
        TournamentBracketMatch(
          id: 'preview-${roundNumbers[round][index]}',
          round: tournamentBracketRoundCode(round, totalRounds),
          matchNumber: roundNumbers[round][index],
          status: TournamentMatchStatus.scheduled,
          side1Label: round == 0
              ? (slots.elementAtOrNull(index * 2)?.isNotEmpty ?? false)
                    ? slots[index * 2]
                    : labels.bye
              : labels.winnerOf(previous[index * 2]),
          side2Label: round == 0
              ? (slots.elementAtOrNull(index * 2 + 1)?.isNotEmpty ?? false)
                    ? slots[index * 2 + 1]
                    : labels.bye
              : labels.winnerOf(previous[index * 2 + 1]),
          isFinished: false,
        ),
      );
    }
  }
  final semifinals = totalRounds >= 2 ? roundNumbers[totalRounds - 2] : null;
  if (category.thirdPlaceMatch == true && semifinals?.length == 2) {
    result.add(
      TournamentBracketMatch(
        id: 'preview-$number',
        round: tournamentThirdPlaceRound,
        matchNumber: number,
        status: TournamentMatchStatus.scheduled,
        side1Label: labels.loserOf(semifinals![0]),
        side2Label: labels.loserOf(semifinals[1]),
        isFinished: false,
      ),
    );
  }
  return result;
}

List<TournamentBracketColumn> buildTournamentBracketColumns(
  List<TournamentBracketMatch> matches,
) {
  final grouped = <String, List<TournamentBracketMatch>>{};
  for (final match in matches) {
    grouped.putIfAbsent(match.round.toUpperCase(), () => []).add(match);
  }
  int order(String round) {
    final index = tournamentBracketRoundOrder.indexOf(round);
    return index < 0 ? tournamentBracketRoundOrder.length : index;
  }

  final rounds =
      grouped.keys.where((round) => round != tournamentThirdPlaceRound).toList()
        ..sort((first, second) => order(first).compareTo(order(second)));
  if (grouped.containsKey(tournamentThirdPlaceRound)) {
    rounds.add(tournamentThirdPlaceRound);
  }
  return [
    for (final round in rounds)
      TournamentBracketColumn(
        round: round,
        matches: [...grouped[round]!]
          ..sort(
            (first, second) => first.matchNumber.compareTo(second.matchNumber),
          ),
      ),
  ];
}

TournamentBracketMatch _toBracketMatch(
  TournamentMatch match,
  List<TournamentMatch> allMatches,
  TournamentCategory category,
  TournamentBracketLabels labels, {
  required bool showPlayerNames,
}) {
  int? winnerPosition;
  if (match.winnerId != null && !match.isDraw) {
    winnerPosition = match.participants
        .where((participant) => participant.registrationId == match.winnerId)
        .firstOrNull
        ?.position;
  }
  return TournamentBracketMatch(
    id: match.id,
    round: match.round,
    matchNumber: match.matchNumber,
    status: match.status,
    score: match.score,
    side1Label: resolveTournamentMatchSideLabel(
      match,
      1,
      allMatches,
      category,
      labels,
      showPlayerNames: showPlayerNames,
    ),
    side2Label: resolveTournamentMatchSideLabel(
      match,
      2,
      allMatches,
      category,
      labels,
      showPlayerNames: showPlayerNames,
    ),
    winnerPosition: winnerPosition,
    isFinished: match.status == TournamentMatchStatus.finished,
  );
}

String resolveTournamentMatchSideLabel(
  TournamentMatch match,
  int position,
  List<TournamentMatch> allMatches,
  TournamentCategory category,
  TournamentBracketLabels labels, {
  required bool showPlayerNames,
}) {
  final registration = match.side(position);
  if (registration != null) {
    final players = registration.playerNames.trim();
    final team = registration.teamLabel.trim();
    return showPlayerNames && players.isNotEmpty ? players : team;
  }
  final round = match.round.toUpperCase();
  if (match.groupId != null || round == 'GROUP') return labels.tbd;
  final feeder = _feederMatch(match, position, allMatches);
  if (round == tournamentThirdPlaceRound) {
    return feeder == null
        ? labels.tbd
        : labels.loserOf(feeder.match.matchNumber);
  }
  if (category.format == TournamentCategoryFormat.doubleElimination &&
      feeder != null) {
    return feeder.loser
        ? labels.loserOf(feeder.match.matchNumber)
        : labels.winnerOf(feeder.match.matchNumber);
  }
  final rounds = <String, List<TournamentMatch>>{};
  for (final item in allMatches.where(
    (item) =>
        item.categoryId == match.categoryId &&
        item.groupId == null &&
        item.round.toUpperCase() != 'GROUP',
  )) {
    rounds.putIfAbsent(item.round.toUpperCase(), () => []).add(item);
  }
  final mainRounds = tournamentBracketRoundOrder
      .where(rounds.containsKey)
      .toList();
  if (mainRounds.indexOf(round) > 0) {
    return feeder == null
        ? labels.tbd
        : labels.winnerOf(feeder.match.matchNumber);
  }
  final single = category.format == TournamentCategoryFormat.singleElimination;
  final slots = resolveTournamentBracketSlots(
    category,
    single ? 1 : category.groupCount,
    single ? category.registrationCount : category.winnersPerGroup ?? 0,
    labels,
  );
  final firstRound = [...?rounds[round]]
    ..sort((first, second) => first.matchNumber.compareTo(second.matchNumber));
  final slot =
      firstRound.indexWhere((item) => item.id == match.id) * 2 + position - 1;
  return slot >= 0 && slot < slots.length && slots[slot].isNotEmpty
      ? slots[slot]
      : labels.bye;
}

({TournamentMatch match, bool loser})? _feederMatch(
  TournamentMatch target,
  int position,
  List<TournamentMatch> matches,
) {
  for (final match in matches) {
    if (match.winnerNextMatchId == target.id &&
        match.winnerNextSlot == position) {
      return (match: match, loser: false);
    }
    if (match.loserNextMatchId == target.id &&
        match.loserNextSlot == position) {
      return (match: match, loser: true);
    }
  }
  return null;
}
