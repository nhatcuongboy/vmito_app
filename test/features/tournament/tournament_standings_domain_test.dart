import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_standings.dart';

void main() {
  test('parses complete standings payload and group metadata', () {
    final group = TournamentStandingGroup.fromJson({
      'group': {
        'id': 'g1',
        'categoryId': 'c1',
        'groupNumber': 1,
        'name': 'A',
      },
      'standings': [
        {
          'categoryRegistrationId': 'r1',
          'registration': {
            'id': 'r1',
            'pair': {
              'name': 'Team One',
              'members': [
                {
                  'player': {'name': 'Player One'},
                },
              ],
            },
          },
          'matchesPlayed': 4,
          'matchesWon': 3,
          'matchesLost': 1,
          'matchesDrawn': 0,
          'matchesForfeited': 1,
          'matchesCancelled': 1,
          'points': 7,
          'pointsFor': 120,
          'pointsAgainst': 88,
          'pointDifference': 32,
          'gamesWon': 7,
          'gamesLost': 3,
          'gameDifference': 4,
          'recentForm': ['W', 'L', 'D', 'W', 'W', 'W'],
          'rank': 1,
        },
      ],
    });

    expect(group.group?.id, 'g1');
    expect(group.group?.name, 'A');
    expect(group.rows.single.categoryRegistrationId, 'r1');
    expect(group.rows.single.pointsAgainst, 88);
    expect(group.rows.single.gamesWon, 7);
    expect(group.rows.single.recentForm, hasLength(5));
    expect(group.rows.single.rank, 1);
  });

  test(
    'overall standings use the same web ordering and retain source group',
    () {
      final groups = [
        TournamentStandingGroup(
          group: const TournamentCategoryGroup(
            id: 'g1',
            categoryId: 'c1',
            number: 1,
            name: 'A',
          ),
          rows: [
            _standing('r1', points: 4, difference: 2, pointsFor: 40),
          ],
        ),
        TournamentStandingGroup(
          group: const TournamentCategoryGroup(
            id: 'g2',
            categoryId: 'c1',
            number: 2,
            name: 'B',
          ),
          rows: [
            _standing('r2', points: 4, difference: 5, pointsFor: 30),
            _standing('r3', points: 2, difference: 20, pointsFor: 80),
          ],
        ),
      ];

      final overall = buildTournamentOverallStandings(groups);

      expect(overall.map((row) => row.standing.registration.id), [
        'r2',
        'r1',
        'r3',
      ]);
      expect(overall.first.rank, 1);
      expect(overall.first.group?.name, 'B');
    },
  );

  test('builds standard and custom bracket slots with feeder labels', () {
    final labels = TournamentBracketLabels(
      winnerOf: (match) => 'W$match',
      loserOf: (match) => 'L$match',
      poolSeed: (rank, pool) => '$rank-$pool',
      ordinal: (rank) => '${rank + 1}',
      bye: 'BYE',
      tbd: 'TBD',
    );
    final category = _category(
      groupCount: 2,
      winnersPerGroup: 2,
      formatConfig: const {
        'playoffs': {
          'seedOrder': ['1-A', '2-B', '1-B', '2-A'],
        },
      },
    );

    expect(
      resolveTournamentBracketSlots(category, 2, 2, labels),
      ['1-A', '2-B', '1-B', '2-A'],
    );
    final preview = buildTournamentEliminationMatches(
      category: category,
      matches: const [],
      labels: labels,
      groupStageMatchCount: 4,
    );
    expect(preview.where((match) => match.round == 'SF'), hasLength(2));
    expect(preview.singleWhere((match) => match.round == 'F').side1Label, 'W5');
  });

  test(
    'double elimination placeholders distinguish winner and loser feeders',
    () {
      final labels = TournamentBracketLabels(
        winnerOf: (match) => 'W$match',
        loserOf: (match) => 'L$match',
        poolSeed: (rank, pool) => '$rank-$pool',
        ordinal: (rank) => '${rank + 1}',
        bye: 'BYE',
        tbd: 'TBD',
      );
      const feeder = TournamentMatch(
        id: 'm1',
        categoryId: 'c1',
        round: 'UB-QF',
        matchNumber: 1,
        status: TournamentMatchStatus.finished,
        participants: [],
        winnerNextMatchId: 'm2',
        winnerNextSlot: 1,
        loserNextMatchId: 'm3',
        loserNextSlot: 1,
        bracketType: 'UPPER',
      );
      const winnerTarget = TournamentMatch(
        id: 'm2',
        categoryId: 'c1',
        round: 'UB-SF',
        matchNumber: 2,
        status: TournamentMatchStatus.scheduled,
        participants: [],
        bracketType: 'UPPER',
      );
      const loserTarget = TournamentMatch(
        id: 'm3',
        categoryId: 'c1',
        round: 'LB-1',
        matchNumber: 3,
        status: TournamentMatchStatus.scheduled,
        participants: [],
        bracketType: 'LOWER',
      );
      final category = _category(
        format: TournamentCategoryFormat.doubleElimination,
      );

      expect(
        resolveTournamentMatchSideLabel(
          winnerTarget,
          1,
          const [feeder, winnerTarget, loserTarget],
          category,
          labels,
          showPlayerNames: false,
        ),
        'W1',
      );
      expect(
        resolveTournamentMatchSideLabel(
          loserTarget,
          1,
          const [feeder, winnerTarget, loserTarget],
          category,
          labels,
          showPlayerNames: false,
        ),
        'L1',
      );
    },
  );
}

TournamentStanding _standing(
  String id, {
  required int points,
  required int difference,
  required int pointsFor,
}) => TournamentStanding(
  registration: TournamentRegistration(id: id, pairName: id),
  matchesPlayed: 2,
  matchesWon: 1,
  matchesLost: 1,
  matchesDrawn: 0,
  matchesForfeited: 0,
  matchesCancelled: 0,
  points: points,
  pointsFor: pointsFor,
  pointDifference: difference,
);

TournamentCategory _category({
  TournamentCategoryFormat format =
      TournamentCategoryFormat.roundRobinToSingleElimination,
  int groupCount = 0,
  int? winnersPerGroup,
  Map<String, dynamic> formatConfig = const {},
}) => TournamentCategory(
  id: 'c1',
  name: 'Doubles',
  type: 'MEN_DOUBLES',
  registrationMode: TournamentRegistrationMode.team,
  format: format,
  registrationCount: 4,
  groupCount: groupCount,
  winnersPerGroup: winnersPerGroup,
  formatConfig: formatConfig,
);
