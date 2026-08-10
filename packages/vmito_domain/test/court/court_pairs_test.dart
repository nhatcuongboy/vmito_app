import 'package:test/test.dart';
import 'package:vmito_domain/vmito_domain.dart';

PositionedPlayer seat(String id, int position) =>
    PositionedPlayer(id: id, position: position);

void main() {
  group('visualSlotOrder', () {
    // The API numbers seats by team, the court draws them by geometry. On a
    // horizontal court those disagree — seat 1 is drawn third.
    test('horizontal reorders, vertical does not', () {
      expect(visualSlotOrder(PairDirection.horizontal), [0, 2, 1, 3]);
      expect(visualSlotOrder(PairDirection.vertical), [0, 1, 2, 3]);
    });
  });

  group('groupPairs — teams', () {
    test('horizontal pairs 0+1 against 2+3', () {
      final pairs = groupPairs(
        [
          seat('a', 0),
          seat('b', 1),
          seat('c', 2),
          seat('d', 3),
        ],
        PairDirection.horizontal,
        CourtFormat.doubles,
      )!;

      expect(pairs.pair1.map((p) => p.id), ['a', 'b']);
      expect(pairs.pair2.map((p) => p.id), ['c', 'd']);
    });

    test('vertical pairs 0+2 against 1+3', () {
      final pairs = groupPairs(
        [
          seat('a', 0),
          seat('b', 1),
          seat('c', 2),
          seat('d', 3),
        ],
        PairDirection.vertical,
        CourtFormat.doubles,
      )!;

      expect(pairs.pair1.map((p) => p.id), ['a', 'c']);
      expect(pairs.pair2.map((p) => p.id), ['b', 'd']);
    });

    test('the team split is not the draw order', () {
      // Both are direction-dependent, and they are different mappings. Merging
      // them would pair the wrong players on a horizontal court.
      final pairs = groupPairs(
        [
          seat('a', 0),
          seat('b', 1),
          seat('c', 2),
          seat('d', 3),
        ],
        PairDirection.horizontal,
        CourtFormat.doubles,
      )!;

      expect(pairs.pair1.map((p) => p.id), isNot(['a', 'c']));
    });
  });

  group('groupPairs — incomplete or malformed courts', () {
    test('three players on a doubles court is no pairing at all', () {
      final pairs = groupPairs(
        [
          seat('a', 0),
          seat('b', 1),
          seat('c', 2),
        ],
        PairDirection.horizontal,
        CourtFormat.doubles,
      );

      expect(pairs, isNull);
    });

    test('one player on a singles court is no pairing', () {
      expect(
        groupPairs(
          [
            seat('a', 0),
          ],
          PairDirection.horizontal,
          CourtFormat.singles,
        ),
        isNull,
      );
    });

    // Four players is not enough on its own — they must occupy four distinct
    // seats in 0..3. Duplicated seats would otherwise yield a one-player side.
    test('four players sharing seats yields no pairing', () {
      expect(
        groupPairs(
          [
            seat('a', 0),
            seat('b', 0),
            seat('c', 2),
            seat('d', 3),
          ],
          PairDirection.horizontal,
          CourtFormat.doubles,
        ),
        isNull,
      );
    });

    test('seats outside 0..3 yield no pairing', () {
      expect(
        groupPairs(
          [
            seat('a', 0),
            seat('b', 1),
            seat('c', 2),
            seat('d', 7),
          ],
          PairDirection.horizontal,
          CourtFormat.doubles,
        ),
        isNull,
      );
    });
  });

  group('groupPairs — inferred format', () {
    test('two players infer singles, four infer doubles', () {
      final singles = groupPairs([
        seat('a', 0),
        seat('b', 1),
      ], PairDirection.horizontal)!;
      expect(singles.format, CourtFormat.singles);

      final doubles = groupPairs([
        seat('a', 0),
        seat('b', 1),
        seat('c', 2),
        seat('d', 3),
      ], PairDirection.horizontal)!;
      expect(doubles.format, CourtFormat.doubles);
    });

    test('an explicit format overrides the head count', () {
      // Four players on a court the host declared singles: the extra two are
      // ignored, and the first two seats play each other.
      final pairs = groupPairs(
        [
          seat('a', 0),
          seat('b', 1),
          seat('c', 2),
          seat('d', 3),
        ],
        PairDirection.horizontal,
        CourtFormat.singles,
      )!;

      expect(pairs.format, CourtFormat.singles);
      expect(pairs.pair1.single.id, 'a');
      expect(pairs.pair2.single.id, 'b');
    });

    test('declaring doubles with only two players yields no pairing', () {
      expect(
        groupPairs(
          [
            seat('a', 0),
            seat('b', 1),
          ],
          PairDirection.horizontal,
          CourtFormat.doubles,
        ),
        isNull,
      );
    });
  });

  test('CourtFormat.playerCount', () {
    expect(CourtFormat.singles.playerCount, 2);
    expect(CourtFormat.doubles.playerCount, 4);
  });
}
