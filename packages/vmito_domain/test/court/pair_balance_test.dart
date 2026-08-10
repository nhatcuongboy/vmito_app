import 'package:test/test.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Mirrors `manualPairStats` in
/// `vmito-fe/src/components/session/CourtPlayerSelectionModal.tsx`.
///
/// Scores are **display ranks**, not level ids — the ids are not in display
/// order, so summing them would rank `Yếu-` (9) above `Khá` (6).
void main() {
  // Ranks, for readability below: Yếu-=0, Yếu=1, Yếu+=2, TBY=3, TB-=4, TB=5,
  // TB+=6, Khá=7, BC=8, CN=9.
  const yeuMinus = 9; // rank 0
  const tb = 4; // rank 5 — also the fallback for an unknown level
  const cn = 8; // rank 9

  group('doubles', () {
    test('sums each side by display rank', () {
      final balance = pairBalance([
        yeuMinus,
        cn,
        tb,
        tb,
      ], CourtFormat.doubles)!;

      expect(balance.pair1Score, 0 + 9);
      expect(balance.pair2Score, 5 + 5);
      expect(balance.scoreDifference, 1);
    });

    test('slots 0+1 are one side and 2+3 the other, regardless of court', () {
      // The selection court always draws pair 1 on the left. This split is
      // deliberately NOT the direction-dependent one `groupPairs` uses.
      final balance = pairBalance([cn, cn, tb, tb], CourtFormat.doubles)!;
      expect(balance.pair1Score, 18);
      expect(balance.pair2Score, 10);
    });

    test('a half-filled side still scores, so the gap updates as you pick', () {
      final balance = pairBalance([cn, null, tb, null], CourtFormat.doubles)!;
      expect(balance.pair1Score, 9);
      expect(balance.pair2Score, 5);
      expect(balance.scoreDifference, 4);
    });

    test('an empty side has no meaningful gap', () {
      expect(pairBalance([cn, tb, null, null], CourtFormat.doubles), isNull);
      expect(pairBalance([null, null, cn, tb], CourtFormat.doubles), isNull);
      expect(pairBalance([], CourtFormat.doubles), isNull);
    });

    test('an unknown level scores as TB rather than zero', () {
      // Scoring it zero would make an unrated player look like the weakest
      // possible partner and skew every suggestion the host eyeballs.
      final unknown = pairBalance([999, null, tb, null], CourtFormat.doubles)!;
      expect(unknown.pair1Score, 5);
      expect(unknown.scoreDifference, 0);
    });
  });

  group('singles', () {
    test('compares the two seats directly', () {
      final balance = pairBalance([yeuMinus, cn], CourtFormat.singles)!;
      expect(balance.pair1Score, 0);
      expect(balance.pair2Score, 9);
      expect(balance.scoreDifference, 9);
    });

    test('needs both seats filled', () {
      expect(pairBalance([cn, null], CourtFormat.singles), isNull);
      expect(pairBalance([null, cn], CourtFormat.singles), isNull);
      expect(pairBalance([cn], CourtFormat.singles), isNull);
    });

    test('ignores anything beyond the first two seats', () {
      final balance = pairBalance([tb, tb, cn, cn], CourtFormat.singles)!;
      expect(balance.scoreDifference, 0);
    });
  });

  test('the gap is absolute — which side is stronger does not matter', () {
    final ab = pairBalance([cn, cn, tb, tb], CourtFormat.doubles)!;
    final ba = pairBalance([tb, tb, cn, cn], CourtFormat.doubles)!;
    expect(ab.scoreDifference, ba.scoreDifference);
  });
}
