import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';

void main() {
  group('MatchUpdateDraft', () {
    test('serializes a winning pair and editable fields', () {
      const draft = MatchUpdateDraft(
        playerIds: ['p1', 'p2', 'p3', 'p4'],
        pair1PlayerIds: ['p1', 'p3'],
        pair2PlayerIds: ['p2', 'p4'],
        noResult: false,
        pair1Score: 21,
        pair2Score: 18,
        isExtra: true,
        notes: '  close game  ',
        shuttlecockCount: 2.5,
      );

      final body = draft.toRequestBody();

      expect(jsonDecode(body['score']! as String), {'pair1': 21, 'pair2': 18});
      expect(body['winnerIds'], ['p1', 'p3']);
      expect(body['isDraw'], isFalse);
      expect(body['playerIds'], ['p1', 'p2', 'p3', 'p4']);
      expect(body['notes'], 'close game');
      expect(body['shuttlecockCount'], 2.5);
    });

    test('clears score and winner when marked as no result', () {
      const draft = MatchUpdateDraft(
        playerIds: ['p1', 'p2'],
        pair1PlayerIds: ['p1'],
        pair2PlayerIds: ['p2'],
        noResult: true,
        pair1Score: 21,
        pair2Score: 18,
        isExtra: false,
        notes: '',
      );

      final body = draft.toRequestBody();

      expect(body.containsKey('score'), isTrue);
      expect(body['score'], isNull);
      expect(body['winnerIds'], isEmpty);
      expect(body['isDraw'], isFalse);
      expect(body.containsKey('shuttlecockCount'), isFalse);
    });

    test('marks equal scores as a draw', () {
      const draft = MatchUpdateDraft(
        playerIds: ['p1', 'p2'],
        pair1PlayerIds: ['p1'],
        pair2PlayerIds: ['p2'],
        noResult: false,
        pair1Score: 15,
        pair2Score: 15,
        isExtra: false,
        notes: '',
      );

      expect(draft.isDraw, isTrue);
      expect(draft.winnerIds, isEmpty);
    });
  });
}
