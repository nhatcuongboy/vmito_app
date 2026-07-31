/// Rally scoring engine.
///
/// Ported line-for-line from `vmito-fe/src/lib/scoring/rally.ts` (260 lines).
/// The web original has **no tests**, so correctness here is pinned by
/// characterization fixtures recorded from the TypeScript — see
/// `fixtures/rally/` and `tool/record_rally_fixtures.mjs`. Any behavioural
/// change must move the fixtures, which moves both languages together.
library;

import 'package:vmito_domain/src/scoring/sport_profile.dart';

/// One set's score. `player3`/`player4` mirror `player1`/`player2` in doubles.
class MatchSet {
  const MatchSet({
    required this.setNumber,
    required this.player1Score,
    required this.player2Score,
    this.player3Score,
    this.player4Score,
  });

  factory MatchSet.fromJson(Map<String, dynamic> json) => MatchSet(
    setNumber: (json['setNumber'] as num).toInt(),
    player1Score: (json['player1Score'] as num).toInt(),
    player2Score: (json['player2Score'] as num).toInt(),
    player3Score: (json['player3Score'] as num?)?.toInt(),
    player4Score: (json['player4Score'] as num?)?.toInt(),
  );

  final int setNumber;
  final int player1Score;
  final int player2Score;
  final int? player3Score;
  final int? player4Score;

  MatchSet copyWith({
    int? setNumber,
    int? player1Score,
    int? player2Score,
    int? player3Score,
    int? player4Score,
  }) => MatchSet(
    setNumber: setNumber ?? this.setNumber,
    player1Score: player1Score ?? this.player1Score,
    player2Score: player2Score ?? this.player2Score,
    player3Score: player3Score ?? this.player3Score,
    player4Score: player4Score ?? this.player4Score,
  );

  /// Keys and omission behaviour match the TypeScript object exactly, so
  /// recorded fixtures compare byte-for-byte.
  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'player1Score': player1Score,
    'player2Score': player2Score,
    if (player3Score != null) 'player3Score': player3Score,
    if (player4Score != null) 'player4Score': player4Score,
  };

  @override
  bool operator ==(Object other) =>
      other is MatchSet &&
      other.setNumber == setNumber &&
      other.player1Score == player1Score &&
      other.player2Score == player2Score &&
      other.player3Score == player3Score &&
      other.player4Score == player4Score;

  @override
  int get hashCode => Object.hash(
    setNumber,
    player1Score,
    player2Score,
    player3Score,
    player4Score,
  );

  @override
  String toString() =>
      'MatchSet($setNumber: $player1Score-$player2Score'
      '${player3Score == null ? '' : ' /$player3Score-$player4Score'})';
}

/// Resolved rules for one match.
class RallyScoringRules {
  const RallyScoringRules({
    required this.pointsToWin,
    required this.winBy,
    required this.cap,
    required this.bestOf,
  });

  final int pointsToWin;

  /// 2 when "win by two" applies, otherwise 1.
  final int winBy;

  /// Hard ceiling; null means none.
  final int? cap;

  /// 1, 3 or 5.
  final int bestOf;

  Map<String, dynamic> toJson() => {
    'pointsToWin': pointsToWin,
    'winBy': winBy,
    'cap': cap,
    'bestOf': bestOf,
  };

  @override
  bool operator ==(Object other) =>
      other is RallyScoringRules &&
      other.pointsToWin == pointsToWin &&
      other.winBy == winBy &&
      other.cap == cap &&
      other.bestOf == bestOf;

  @override
  int get hashCode => Object.hash(pointsToWin, winBy, cap, bestOf);

  @override
  String toString() =>
      'RallyScoringRules(to $pointsToWin, by $winBy, cap $cap, bo$bestOf)';
}

/// Which rule set a match falls under. `GROUP` and `FINAL` are exact round
/// values; everything else is knockout.
enum ScoringStage { group, knockout, best }

ScoringStage _stageOfRound(String? round) {
  if (round == 'GROUP') return ScoringStage.group;
  if (round == 'F') return ScoringStage.best;
  return ScoringStage.knockout;
}

/// Per-stage overrides on a category. A null field means "inherit".
class StageScoringCategory {
  const StageScoringCategory({
    this.matchFormat,
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

  final MatchFormat? matchFormat;
  final int? pointsToWin;
  final bool? winByTwo;
  final int? pointCap;
  final int? knockoutPointsToWin;
  final bool? knockoutWinByTwo;
  final int? knockoutPointCap;
  final int? finalPointsToWin;
  final bool? finalWinByTwo;
  final int? finalPointCap;
}

/// The match-level half of the rules input.
class ScoringMatch {
  const ScoringMatch({
    this.matchFormat,
    this.pointsToWin,
    this.winByTwo,
    this.pointCap,
    this.round,
    this.category,
  });

  final MatchFormat? matchFormat;
  final int? pointsToWin;
  final bool? winByTwo;
  final int? pointCap;
  final String? round;
  final StageScoringCategory? category;
}

int _bestOfFromMatchFormat(MatchFormat? format) => switch (format) {
  MatchFormat.bestOf5 => 5,
  MatchFormat.bestOf3 => 3,
  _ => 1,
};

/// Resolves the rules for a match.
///
/// The cascade is match → category-for-stage → sport default, and the
/// stage layer itself falls **upward**: FINAL reads final, then knockout, then
/// the category base. Getting that order wrong silently changes the scoring of
/// every final.
RallyScoringRules defaultRules({
  ScoringMatch? match,
  MatchFormat? format,
  SportType? sportType,
}) {
  final fallback = getTournamentSportProfile(sportType).defaultScoring;

  // The TypeScript overload takes either a match object or a bare format.
  // Split here into two named parameters rather than a union.
  if (match == null) {
    return RallyScoringRules(
      pointsToWin: fallback.pointsToWin,
      winBy: fallback.winByTwo ? 2 : 1,
      cap: fallback.pointCap,
      bestOf: _bestOfFromMatchFormat(format ?? fallback.matchFormat),
    );
  }

  final category = match.category;
  final stage = _stageOfRound(match.round);
  final resolvedFormat =
      match.matchFormat ?? category?.matchFormat ?? fallback.matchFormat;

  int resolveCategoryPoints() {
    if (category == null) return fallback.pointsToWin;
    return switch (stage) {
      ScoringStage.best =>
        category.finalPointsToWin ??
            category.knockoutPointsToWin ??
            category.pointsToWin ??
            fallback.pointsToWin,
      ScoringStage.knockout =>
        category.knockoutPointsToWin ??
            category.pointsToWin ??
            fallback.pointsToWin,
      ScoringStage.group => category.pointsToWin ?? fallback.pointsToWin,
    };
  }

  bool resolveCategoryWinByTwo() {
    if (category == null) return fallback.winByTwo;
    return switch (stage) {
      ScoringStage.best =>
        category.finalWinByTwo ??
            category.knockoutWinByTwo ??
            category.winByTwo ??
            fallback.winByTwo,
      ScoringStage.knockout =>
        category.knockoutWinByTwo ?? category.winByTwo ?? fallback.winByTwo,
      ScoringStage.group => category.winByTwo ?? fallback.winByTwo,
    };
  }

  int? resolveCategoryCap() {
    if (category == null) return fallback.pointCap;
    return switch (stage) {
      ScoringStage.best =>
        category.finalPointCap ??
            category.knockoutPointCap ??
            category.pointCap ??
            fallback.pointCap,
      ScoringStage.knockout =>
        category.knockoutPointCap ?? category.pointCap ?? fallback.pointCap,
      ScoringStage.group => category.pointCap ?? fallback.pointCap,
    };
  }

  return RallyScoringRules(
    pointsToWin: match.pointsToWin ?? resolveCategoryPoints(),
    winBy: (match.winByTwo ?? resolveCategoryWinByTwo()) ? 2 : 1,
    cap: match.pointCap ?? resolveCategoryCap(),
    bestOf: _bestOfFromMatchFormat(resolvedFormat),
  );
}

/// Whether a set has ended, and who took it.
class SetOutcome {
  const SetOutcome({required this.complete, required this.winner});

  final bool complete;

  /// 1 or 2, or null while the set is live.
  final int? winner;
}

SetOutcome isSetComplete(int a, int b, RallyScoringRules rules) {
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  final cap = rules.cap;

  final complete =
      (cap != null && hi >= cap) ||
      (hi >= rules.pointsToWin && hi - lo >= rules.winBy);

  if (!complete) return const SetOutcome(complete: false, winner: null);
  return SetOutcome(complete: true, winner: a > b ? 1 : 2);
}

/// Sets won by each side.
class SetWins {
  const SetWins(this.side1, this.side2);

  final int side1;
  final int side2;
}

SetWins setWins(List<MatchSet> sets, RallyScoringRules rules) {
  var side1 = 0;
  var side2 = 0;
  for (final set in sets) {
    final winner = isSetComplete(
      set.player1Score,
      set.player2Score,
      rules,
    ).winner;
    if (winner == 1) {
      side1++;
    } else if (winner == 2) {
      side2++;
    }
  }
  return SetWins(side1, side2);
}

int setsToWin(RallyScoringRules rules) => switch (rules.bestOf) {
  5 => 3,
  3 => 2,
  _ => 1,
};

/// Whether the match has ended, and who won.
class MatchOutcome {
  const MatchOutcome({required this.complete, required this.winnerSide});

  final bool complete;
  final int? winnerSide;
}

MatchOutcome isMatchComplete(List<MatchSet> sets, RallyScoringRules rules) {
  final wins = setWins(sets, rules);
  final need = setsToWin(rules);
  if (wins.side1 >= need) {
    return const MatchOutcome(complete: true, winnerSide: 1);
  }
  if (wins.side2 >= need) {
    return const MatchOutcome(complete: true, winnerSide: 2);
  }
  return const MatchOutcome(complete: false, winnerSide: null);
}

/// True when one more point for [sideToScore] would end the match.
bool isMatchPoint(
  List<MatchSet> sets,
  int currentSetIndex,
  int sideToScore,
  RallyScoringRules rules,
) {
  if (currentSetIndex < 0 || currentSetIndex >= sets.length) return false;
  final current = sets[currentSetIndex];

  final a = current.player1Score + (sideToScore == 1 ? 1 : 0);
  final b = current.player2Score + (sideToScore == 2 ? 1 : 0);

  final outcome = isSetComplete(a, b, rules);
  if (!outcome.complete || outcome.winner != sideToScore) return false;

  final projected = [
    for (var i = 0; i < sets.length; i++)
      if (i == currentSetIndex)
        sets[i].copyWith(player1Score: a, player2Score: b)
      else
        sets[i],
  ];
  return isMatchComplete(projected, rules).complete;
}

int currentSetIndex(List<MatchSet> sets) =>
    sets.isNotEmpty ? sets.length - 1 : 0;

MatchSet _newSet(int setNumber, {required bool isDoubles}) => MatchSet(
  setNumber: setNumber,
  player1Score: 0,
  player2Score: 0,
  player3Score: isDoubles ? 0 : null,
  player4Score: isDoubles ? 0 : null,
);

/// Applies a single point (or undo) and returns the new set list.
///
/// Three behaviours worth keeping straight, all inherited from the web:
/// - a `+1` on a finished match is ignored, but an undo still applies;
/// - in doubles, player3/4 mirror player1/2 rather than holding their own
///   scores;
/// - completing a set that does not finish the match appends the next set.
List<MatchSet> applyDelta(
  List<MatchSet> sets,
  int side,
  int delta,
  RallyScoringRules rules, {
  required bool isDoubles,
}) {
  final working = sets.isNotEmpty
      ? [...sets]
      : [_newSet(1, isDoubles: isDoubles)];

  if (delta == 1 && isMatchComplete(working, rules).complete) {
    return working;
  }

  final lastIndex = working.length - 1;
  final current = working[lastIndex];

  MatchSet updated;
  if (side == 1) {
    final score = _atLeastZero(current.player1Score + delta);
    updated = current.copyWith(
      player1Score: score,
      player3Score: isDoubles ? score : current.player3Score,
    );
  } else {
    final score = _atLeastZero(current.player2Score + delta);
    updated = current.copyWith(
      player2Score: score,
      player4Score: isDoubles ? score : current.player4Score,
    );
  }
  working[lastIndex] = updated;

  final setDone = isSetComplete(
    updated.player1Score,
    updated.player2Score,
    rules,
  ).complete;
  final matchDone = isMatchComplete(working, rules).complete;

  if (delta == 1 && setDone && !matchDone) {
    working.add(_newSet(updated.setNumber + 1, isDoubles: isDoubles));
  }
  return working;
}

int _atLeastZero(int value) => value < 0 ? 0 : value;

/// `"21-19, 15-21, 21-18"`.
///
/// Sets that are still 0-0 are dropped, except the first — so a match that has
/// not started renders as `"0-0"` rather than an empty string.
String buildScoreString(List<MatchSet> sets) {
  final parts = <String>[];
  for (var i = 0; i < sets.length; i++) {
    final set = sets[i];
    if (set.player1Score > 0 || set.player2Score > 0 || i == 0) {
      parts.add('${set.player1Score}-${set.player2Score}');
    }
  }
  return parts.join(', ');
}
