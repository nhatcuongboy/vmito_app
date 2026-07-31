import 'package:test/test.dart';
import 'package:vmito_domain/src/scoring/rally.dart';
import 'package:vmito_domain/src/scoring/sport_profile.dart';

import '../fixtures.dart';

/// Asserts the Dart rally engine reproduces the TypeScript exactly.
///
/// Every expectation here was *recorded* from `vmito-fe/src/lib/scoring/rally.ts`
/// — none was written by hand. A failure means the port diverged, not that a
/// number was mistyped.
void main() {
  group('defaultRules', () {
    test('reproduces the full stage cascade', () {
      final cases = loadFixture('rally/default_rules.json');
      expect(cases, isNotEmpty);

      for (final testCase in cases) {
        final input = testCase['input'] as Map<String, dynamic>;
        final expected = _rules(testCase['output'] as Map<String, dynamic>);
        final sport = _sportType(input['sportType'] as String?);

        final actual = input['kind'] == 'format'
            ? defaultRules(
                format: _matchFormat(input['format'] as String?),
                sportType: sport,
              )
            : defaultRules(
                match: _scoringMatch(input['match'] as Map<String, dynamic>),
                sportType: sport,
              );

        expect(actual, expected, reason: 'input: $input');
      }
    });
  });

  group('isSetComplete', () {
    test('matches on every score pair up to 32-32', () {
      final cases = loadFixture('rally/is_set_complete.json');
      expect(cases, hasLength(greaterThan(5000)));

      for (final testCase in cases) {
        final input = testCase['input'] as Map<String, dynamic>;
        final expected = testCase['output'] as Map<String, dynamic>;

        final actual = isSetComplete(
          (input['a'] as num).toInt(),
          (input['b'] as num).toInt(),
          _rules(input['rules'] as Map<String, dynamic>),
        );

        expect(actual.complete, expected['complete'], reason: 'input: $input');
        expect(actual.winner, expected['winner'], reason: 'input: $input');
      }
    });
  });

  group('applyDelta over whole matches', () {
    test('every point of every recorded rally agrees', () {
      final cases = loadFixture('rally/rallies.json');
      expect(cases, isNotEmpty);

      for (final testCase in cases) {
        final input = testCase['input'] as Map<String, dynamic>;
        final output = testCase['output'] as Map<String, dynamic>;
        final rules = _rules(input['rules'] as Map<String, dynamic>);
        final isDoubles = input['isDoubles'] as bool;
        final script = (input['script'] as List<dynamic>)
            .map((side) => (side as num).toInt())
            .toList();
        final steps = (output['steps'] as List<dynamic>)
            .cast<Map<String, dynamic>>();

        var sets = <MatchSet>[];
        for (var i = 0; i < script.length; i++) {
          sets = applyDelta(sets, script[i], 1, rules, isDoubles: isDoubles);
          final step = steps[i];
          final where = 'case ${input['rules']} doubles=$isDoubles step $i';

          // Compare the serialised form: it catches a missing player3Score in
          // doubles, which a field-by-field check on the common fields would
          // silently pass.
          expect(
            sets.map((set) => set.toJson()).toList(),
            step['sets'],
            reason: where,
          );
          expect(buildScoreString(sets), step['scoreString'], reason: where);

          final wins = setWins(sets, rules);
          expect(wins.side1, (step['setWins'] as Map)['side1'], reason: where);
          expect(wins.side2, (step['setWins'] as Map)['side2'], reason: where);

          final complete = isMatchComplete(sets, rules);
          final expectedComplete =
              step['matchComplete'] as Map<String, dynamic>;
          expect(
            complete.complete,
            expectedComplete['complete'],
            reason: where,
          );
          expect(
            complete.winnerSide,
            expectedComplete['winnerSide'],
            reason: where,
          );

          final index = currentSetIndex(sets);
          expect(index, step['currentSetIndex'], reason: where);
          expect(
            isMatchPoint(sets, index, 1, rules),
            step['matchPointSide1'],
            reason: where,
          );
          expect(
            isMatchPoint(sets, index, 2, rules),
            step['matchPointSide2'],
            reason: where,
          );
        }

        expect(
          sets.map((set) => set.toJson()).toList(),
          output['finalSets'],
          reason: 'final sets for ${input['rules']}',
        );
      }
    });
  });

  group('applyDelta edge cases', () {
    test('undo, clamping and the completed-match lock all agree', () {
      final cases = loadFixture('rally/apply_delta_edge_cases.json');

      for (final testCase in cases) {
        final input = testCase['input'] as Map<String, dynamic>;
        final actual = applyDelta(
          _sets(input['sets'] as List<dynamic>),
          (input['side'] as num).toInt(),
          (input['delta'] as num).toInt(),
          _rules(input['rules'] as Map<String, dynamic>),
          isDoubles: input['isDoubles'] as bool,
        );

        expect(
          actual.map((set) => set.toJson()).toList(),
          testCase['output'],
          reason: 'input: $input',
        );
      }
    });
  });

  group('buildScoreString', () {
    test('drops empty trailing sets but keeps the first', () {
      for (final testCase in loadFixture('rally/build_score_string.json')) {
        expect(
          buildScoreString(_sets(testCase['input'] as List<dynamic>)),
          testCase['output'],
          reason: 'input: ${testCase['input']}',
        );
      }
    });
  });

  group('setsToWin', () {
    test('matches for every bestOf', () {
      for (final testCase in loadFixture('rally/sets_to_win.json')) {
        expect(
          setsToWin(_rules(testCase['input'] as Map<String, dynamic>)),
          testCase['output'],
        );
      }
    });
  });
}

// --- decoding helpers ------------------------------------------------------

RallyScoringRules _rules(Map<String, dynamic> json) => RallyScoringRules(
  pointsToWin: (json['pointsToWin'] as num).toInt(),
  winBy: (json['winBy'] as num).toInt(),
  cap: (json['cap'] as num?)?.toInt(),
  bestOf: (json['bestOf'] as num).toInt(),
);

List<MatchSet> _sets(List<dynamic> json) =>
    json.cast<Map<String, dynamic>>().map(MatchSet.fromJson).toList();

SportType? _sportType(String? value) => switch (value) {
  'BADMINTON' => SportType.badminton,
  'PICKLEBALL' => SportType.pickleball,
  _ => null,
};

MatchFormat? _matchFormat(String? value) => switch (value) {
  'BEST_OF_1' => MatchFormat.bestOf1,
  'BEST_OF_3' => MatchFormat.bestOf3,
  'BEST_OF_5' => MatchFormat.bestOf5,
  _ => null,
};

ScoringMatch _scoringMatch(Map<String, dynamic> json) {
  final category = json['category'] as Map<String, dynamic>?;
  return ScoringMatch(
    matchFormat: _matchFormat(json['matchFormat'] as String?),
    pointsToWin: (json['pointsToWin'] as num?)?.toInt(),
    winByTwo: json['winByTwo'] as bool?,
    pointCap: (json['pointCap'] as num?)?.toInt(),
    round: json['round'] as String?,
    category: category == null
        ? null
        : StageScoringCategory(
            matchFormat: _matchFormat(category['matchFormat'] as String?),
            pointsToWin: (category['pointsToWin'] as num?)?.toInt(),
            winByTwo: category['winByTwo'] as bool?,
            pointCap: (category['pointCap'] as num?)?.toInt(),
            knockoutPointsToWin: (category['knockoutPointsToWin'] as num?)
                ?.toInt(),
            knockoutWinByTwo: category['knockoutWinByTwo'] as bool?,
            knockoutPointCap: (category['knockoutPointCap'] as num?)?.toInt(),
            finalPointsToWin: (category['finalPointsToWin'] as num?)?.toInt(),
            finalWinByTwo: category['finalWinByTwo'] as bool?,
            finalPointCap: (category['finalPointCap'] as num?)?.toInt(),
          ),
  );
}
