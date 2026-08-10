import 'package:test/test.dart';
import 'package:vmito_domain/vmito_domain.dart';

import '../fixtures.dart';

/// Replays the corpus recorded from `vmito-fe/src/utils/match-repeat-warning.ts`.
///
/// Re-record with:
///   cd ../vmito-fe && npm run record:match-repeat-fixtures
void main() {
  final cases = loadFixture('match_repeat_warning/warnings.json');

  test('the corpus is non-trivial', () {
    // A corpus that never warns would pass against a function returning
    // `none`, so assert both outcomes are represented before trusting it.
    final warned = cases.where(
      (c) => (c['output'] as Map)['hasWarning'] == true,
    );
    expect(warned, isNotEmpty);
    expect(warned.length, lessThan(cases.length));
  });

  for (final testCase in cases) {
    final input = testCase['input'] as Map<String, dynamic>;
    final expected = testCase['output'] as Map<String, dynamic>;

    test(input['name'] as String, () {
      final actual = getMatchRepeatWarning(
        [
          for (final match in input['history'] as List)
            PlayedMatch(
              players: _seats((match as Map)['players'] as List),
              direction: _direction(match['direction'] as String),
            ),
        ],
        _seats(input['current'] as List),
        direction: _direction(input['direction'] as String),
        format: _format(input['matchType'] as String?),
      );

      expect(actual.hasWarning, expected['hasWarning']);
      _expectItems(actual.repeatedTeammates, expected['repeatedTeammates']);
      _expectItems(actual.repeatedOpponents, expected['repeatedOpponents']);
    });
  }
}

void _expectItems(List<RepeatWarningItem> actual, dynamic expected) {
  final rows = (expected as List).cast<Map<String, dynamic>>();
  expect(actual, hasLength(rows.length));
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    expect(actual[i].key, row['key'], reason: 'key at $i');
    expect(actual[i].totalCount, row['totalCount'], reason: 'total at $i');
    expect(
      actual[i].historyCount,
      row['historyCount'],
      reason: 'history at $i',
    );

    final players = (row['players'] as List).cast<Map<String, dynamic>>();
    final (left, right) = actual[i].players;
    expect(left.id, players[0]['id']);
    expect(left.playerNumber, players[0]['playerNumber']);
    expect(right.id, players[1]['id']);
    expect(right.playerNumber, players[1]['playerNumber']);
  }
}

List<PositionedPlayer> _seats(List<dynamic> raw) => [
  for (final seat in raw.cast<Map<String, dynamic>>())
    PositionedPlayer(
      id: seat['id'] as String,
      position: seat['position'] as int,
      name: 'Player ${seat['id']}',
      playerNumber:
          int.tryParse((seat['id'] as String).replaceAll(RegExp(r'\D'), '')) ??
          (seat['position'] as int) + 1,
    ),
];

PairDirection _direction(String wire) =>
    wire == 'VERTICAL' ? PairDirection.vertical : PairDirection.horizontal;

CourtFormat? _format(String? wire) => switch (wire) {
  'singles' => CourtFormat.singles,
  'doubles' => CourtFormat.doubles,
  _ => null,
};
