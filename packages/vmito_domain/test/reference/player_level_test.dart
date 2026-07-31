import 'package:test/test.dart';
import 'package:vmito_domain/src/reference/player_level.dart';

import '../fixtures.dart';

/// Pins the level table against the TypeScript it was ported from.
///
/// Recorded with `npm run record:level-fixtures` in vmito-fe; the JS suite
/// asserts the same files.
void main() {
  group('table', () {
    test('matches the recorded definitions, in display order', () {
      final expected = loadFixture('levels/definitions.json');

      expect(levelDefinitions, hasLength(expected.length));
      for (var i = 0; i < expected.length; i++) {
        final actual = levelDefinitions[i];
        expect(actual.id, expected[i]['id'], reason: 'row $i id');
        expect(actual.code, expected[i]['code'], reason: 'row $i code');
        expect(
          actual.shortLabel,
          expected[i]['shortLabel'],
          reason: 'row $i label',
        );
        expect(actual.rank, expected[i]['rank'], reason: 'row $i rank');
      }
    });

    test('numeric order is NOT display order', () {
      // The whole reason this file exists. 9 and 10 are the two beginner
      // half-steps and they bracket 1, so `..sort()` on raw ids is wrong.
      final ids = validLevels;

      expect(ids.take(3), [9, 1, 10]);
      expect(ids, isNot(orderedEquals([...ids]..sort())));
    });
  });

  group('levelRank', () {
    test('matches the recorded ranks, including unknown ids', () {
      for (final testCase in loadFixture('levels/ranks.json')) {
        final input = (testCase['input'] as num).toInt();
        expect(levelRank(input), testCase['output'], reason: 'level $input');
      }
    });
  });

  group('sortByRank', () {
    test('reproduces every recorded ordering', () {
      final cases = loadFixture('levels/sorted.json');
      expect(cases, isNotEmpty);

      for (final testCase in cases) {
        final input = (testCase['input'] as List<dynamic>)
            .map((level) => (level as num).toInt())
            .toList();
        final expected = (testCase['output'] as List<dynamic>)
            .map((level) => (level as num).toInt())
            .toList();

        expect(sortByRank(input), expected, reason: 'input: $input');
      }
    });

    test('does not mutate its argument', () {
      final original = [10, 9, 1];
      sortByRank(original);
      expect(original, [10, 9, 1]);
    });
  });

  group('levelRange', () {
    test('spans display order, not numeric order', () {
      // The bug this guards: a numeric range over [1, 9, 10] reads
      // "Yếu → Yếu+" and hides that beginners below Yếu are welcome.
      final range = levelRange([1, 9, 10]);

      expect(range?.lowest, 9);
      expect(range?.highest, 10);
      expect(levelShortLabel(range!.lowest), 'Yếu-');
      expect(levelShortLabel(range.highest), 'Yếu+');
    });

    test('is null for an empty list — "all levels welcome"', () {
      // An empty requiredLevels means no restriction. Rendering it as a range
      // would invent a limit the host never set.
      expect(levelRange(const []), isNull);
    });

    test('ignores ids that are not in the table', () {
      expect(levelRange([99, 3, 5])?.lowest, 3);
      expect(levelRange([99, 3, 5])?.highest, 5);
      expect(levelRange([99, 100]), isNull);
    });
  });

  group('levelShortLabel', () {
    test('returns null for an unknown level rather than the raw number', () {
      expect(levelShortLabel(9), 'Yếu-');
      expect(levelShortLabel(8), 'CN');
      expect(levelShortLabel(99), isNull);
    });
  });
}
