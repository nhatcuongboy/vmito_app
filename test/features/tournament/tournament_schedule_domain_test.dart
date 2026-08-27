import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';

void main() {
  test('parses complete schedule match data', () {
    final match = TournamentMatch.fromJson({
      'id': 'm1',
      'categoryId': 'c1',
      'groupId': 'g1',
      'round': 'GROUP',
      'matchNumber': 4,
      'matchCode': 'A-04',
      'status': 'FINISHED',
      'startTime': '2026-08-27T01:00:00Z',
      'endTime': '2026-08-27T01:42:00Z',
      'courtId': 'court-1',
      'court': {'id': 'court-1', 'courtNumber': 2, 'courtName': 'Center'},
      'refereeId': 'umpire-1',
      'referee': {'id': 'umpire-1', 'name': 'Linh', 'userId': 'user-1'},
      'sets': [
        {'setNumber': 1, 'player1Score': 21, 'player2Score': 18},
        {'setNumber': 2, 'player1Score': 21, 'player2Score': 19},
      ],
      'winnerId': 'r1',
      'winnerNextMatchId': 'm2',
      'winnerNextSlot': 1,
      'participants': [
        {
          'position': 1,
          'categoryRegistrationId': 'r1',
          'categoryRegistration': {
            'id': 'r1',
            'pair': {
              'name': 'Đội Ánh Dương',
              'members': [
                {
                  'player': {'id': 'p1', 'name': 'Ánh'},
                },
                {
                  'player': {'id': 'p2', 'name': 'Dương'},
                },
              ],
            },
          },
        },
      ],
    });

    expect(match.matchCode, 'A-04');
    expect(match.court?.number, 2);
    expect(match.referee?.userId, 'user-1');
    expect(match.sets, hasLength(2));
    expect(match.side(1)?.playerNames, 'Ánh / Dương');
    expect(match.winnerNextSlot, 1);
  });

  test('Vietnamese search, all filters, and scheduled-first sorting work', () {
    final scheduledLater = _match(
      id: 'later',
      number: 2,
      start: DateTime(2026, 8, 28, 10),
      courtId: 'court-1',
      team: 'Đội Ánh Dương',
      registrationId: 'r1',
      refereeId: 'ref-user',
    );
    final scheduledEarlier = _match(
      id: 'earlier',
      number: 3,
      start: DateTime(2026, 8, 28, 8),
      courtId: 'court-1',
      team: 'Đội Ánh Dương',
      registrationId: 'r1',
      refereeId: 'ref-user',
    );
    final unscheduled = _match(
      id: 'unscheduled',
      number: 1,
      team: 'Đội Ánh Dương',
      registrationId: 'r1',
      refereeId: 'ref-user',
    );

    final result = filterAndSortTournamentMatches(
      [unscheduled, scheduledLater, scheduledEarlier],
      TournamentScheduleFilters(
        query: 'anh duong',
        categoryIds: const {'c1'},
        rounds: const {'GROUP'},
        courtIds: const {'court-1'},
        statuses: const {TournamentScheduleStatusFilter.upcoming},
        teamIds: const {'r1'},
        dateFrom: DateTime(2026, 8, 28),
        dateTo: DateTime(2026, 8, 28),
        refereeOnly: true,
      ),
      currentUserId: 'ref-user',
      ownAssignmentIds: const {'later', 'earlier'},
    );

    expect(result.map((match) => match.id), ['earlier', 'later']);
    expect(normalizeTournamentSearch('Đặng Ánh'), 'dang anh');
  });

  test('unresolved bracket slots use feeder labels', () {
    final feeder = _match(id: 'm1', number: 7).copyWith();
    final linked = TournamentMatch(
      id: feeder.id,
      categoryId: feeder.categoryId,
      round: feeder.round,
      matchNumber: feeder.matchNumber,
      status: feeder.status,
      participants: feeder.participants,
      winnerNextMatchId: 'm2',
      winnerNextSlot: 1,
    );
    final target = _match(id: 'm2', number: 8);

    expect(
      tournamentMatchSideLabel(
        target,
        1,
        allMatches: [linked, target],
        toBeDetermined: 'TBD',
        winnerOfMatch: (number) => 'Winner $number',
        loserOfMatch: (number) => 'Loser $number',
      ),
      'Winner 7',
    );
    expect(
      tournamentMatchSideLabel(
        target,
        2,
        allMatches: [linked, target],
        toBeDetermined: 'TBD',
        winnerOfMatch: (number) => 'Winner $number',
        loserOfMatch: (number) => 'Loser $number',
      ),
      'TBD',
    );
  });

  test('unresolved bracket slots derive conventional semifinal feeders', () {
    const semifinal1 = TournamentMatch(
      id: 'sf1',
      categoryId: 'c1',
      round: 'SF',
      matchNumber: 11,
      status: TournamentMatchStatus.scheduled,
      participants: [],
    );
    const semifinal2 = TournamentMatch(
      id: 'sf2',
      categoryId: 'c1',
      round: 'SF',
      matchNumber: 12,
      status: TournamentMatchStatus.scheduled,
      participants: [],
    );
    const finalMatch = TournamentMatch(
      id: 'final',
      categoryId: 'c1',
      round: 'F',
      matchNumber: 13,
      status: TournamentMatchStatus.scheduled,
      participants: [],
    );

    expect(
      tournamentMatchSideLabel(
        finalMatch,
        2,
        allMatches: [semifinal1, semifinal2, finalMatch],
        toBeDetermined: 'TBD',
        winnerOfMatch: (number) => 'Winner $number',
        loserOfMatch: (number) => 'Loser $number',
      ),
      'Winner 12',
    );
  });

  test('bracket becomes ready only after every group match finishes', () {
    const category = TournamentCategory(
      id: 'c1',
      name: 'Open',
      type: 'OPEN',
      registrationMode: TournamentRegistrationMode.team,
      format: TournamentCategoryFormat.roundRobinToSingleElimination,
      registrationCount: 4,
    );

    expect(
      tournamentCategoryReadyForBracket(category, [
        _match(
          id: 'm1',
          number: 1,
          status: TournamentMatchStatus.finished,
          groupId: 'g1',
        ),
      ]),
      isTrue,
    );
    expect(
      tournamentCategoryReadyForBracket(category, [
        _match(id: 'm1', number: 1, groupId: 'g1'),
      ]),
      isFalse,
    );
  });

  test(
    'realtime merge changes one match and preserves unrelated references',
    () {
      final current = _match(id: 'm1', number: 1);
      final untouched = _match(id: 'm2', number: 2);
      final merged = [
        for (final match in [current, untouched])
          if (match.id == 'm1')
            mergeTournamentRealtimeMatch(match, {
              'matchId': 'm1',
              'status': 'IN_PROGRESS',
              'startTime': '2026-08-27T01:00:00Z',
              'currentSet': {'setNumber': 1, 'side1': 10, 'side2': 8},
            })
          else
            match,
      ];

      expect(merged.first.status, TournamentMatchStatus.inProgress);
      expect(merged.first.sets.single.player1Score, 10);
      expect(identical(merged.last, untouched), isTrue);
    },
  );
}

TournamentMatch _match({
  required String id,
  required int number,
  TournamentMatchStatus status = TournamentMatchStatus.scheduled,
  DateTime? start,
  String? courtId,
  String? team,
  String? registrationId,
  String? refereeId,
  String? groupId,
}) => TournamentMatch(
  id: id,
  categoryId: 'c1',
  groupId: groupId,
  round: 'GROUP',
  matchNumber: number,
  status: status,
  startTime: start,
  courtId: courtId,
  referee: refereeId == null
      ? null
      : TournamentUmpire(id: 'u1', name: 'Ref', userId: refereeId),
  participants: team == null
      ? const []
      : [
          TournamentMatchParticipant(
            position: 1,
            registrationId: registrationId!,
            registration: TournamentRegistration(
              id: registrationId,
              pairName: team,
            ),
          ),
        ],
);
