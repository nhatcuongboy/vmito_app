import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_podium.dart';
import 'package:vmito_app/features/tournament/domain/tournament_pulse.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

void main() {
  test('parses detail counts, nullable fields, linked and inline venues', () {
    final tournament = TournamentDetail.fromJson({
      'id': 't1',
      'slug': 'vmito-open',
      'name': 'Vmito Open',
      'startDate': '2026-08-25T01:00:00Z',
      'endDate': '2026-08-26T01:00:00Z',
      'hostId': 'host-1',
      'status': 'IN_PROGRESS',
      'isPublished': true,
      '_count': {'players': 12, 'pairs': 6},
      'categories': [
        {
          'id': 'c1',
          'name': 'Đôi nam',
          'type': 'MEN_DOUBLES',
          'registrationMode': 'TEAM',
          'format': 'ROUND_ROBIN_TO_SE',
          '_count': {'registrations': 6},
          'formatConfig': {
            'roundRobin': {'winPoints': 3, 'tiePoints': 1},
          },
        },
      ],
      'tournamentVenues': [
        {
          'id': 'tv1',
          'isPrimary': true,
          'venue': {
            'name': 'Vmito Arena',
            'newAddress': '1 Nguyễn Huệ',
            'newCity': 'Hồ Chí Minh',
            'coverPhoto': 'https://example.com/venue.jpg',
          },
        },
        {
          'id': 'tv2',
          'name': 'Sân phụ',
          'address': '2 Lê Lợi',
          'lat': 10.7,
          'lng': 106.6,
        },
      ],
    });

    expect(tournament.status, TournamentStatus.inProgress);
    expect(tournament.playerCount, 12);
    expect(tournament.registrationCount, 6);
    expect(tournament.primaryVenue?.name, 'Vmito Arena');
    expect(tournament.resolvedCoverPhoto, 'https://example.com/venue.jpg');
    expect(tournament.venues.last.address, '2 Lê Lợi');
    expect(tournament.categories.single.winPoints, 3);
    expect(tournament.categories.single.tiePoints, 1);
    expect(tournament.categories.single.lossPoints, 0);
  });

  test('pulse prioritizes a live match before the next scheduled match', () {
    final matches = [
      _match(
        id: 'scheduled',
        status: TournamentMatchStatus.scheduled,
        startTime: DateTime(2026, 8, 25, 9),
      ),
      _match(id: 'live', status: TournamentMatchStatus.inProgress),
    ];

    final pulse = selectTournamentPulse(matches, TournamentStatus.inProgress);

    expect(pulse.kind, TournamentPulseKind.live);
    expect(pulse.match?.id, 'live');
  });

  test(
    'computes champion, runner-up and co-bronze from elimination matches',
    () {
      final category = _category(TournamentCategoryFormat.singleElimination);
      final finalMatch = _finishedMatch(
        id: 'final',
        round: 'F',
        side1: 'Đội A',
        side2: 'Đội B',
        winnerId: 'r1',
      );
      final semifinal1 = _finishedMatch(
        id: 'sf1',
        round: 'SF',
        side1: 'Đội A',
        side2: 'Đội C',
        winnerId: 'r1',
      );
      final semifinal2 = _finishedMatch(
        id: 'sf2',
        round: 'SF',
        side1: 'Đội B',
        side2: 'Đội D',
        winnerId: 'r1',
      );

      final podium = computeTournamentPodium(
        category: category,
        matches: [finalMatch, semifinal1, semifinal2],
        standings: const [],
      );

      expect(podium.state, TournamentPodiumState.decided);
      expect(podium.entries.map((entry) => entry.rank), [1, 2, 3, 3]);
      expect(podium.entries.where((entry) => entry.tied), hasLength(2));
    },
  );

  test('round robin leader is provisional while matches remain', () {
    final category = _category(TournamentCategoryFormat.roundRobin);
    final podium = computeTournamentPodium(
      category: category,
      matches: [
        _match(
          id: 'm1',
          status: TournamentMatchStatus.inProgress,
          groupId: 'g1',
        ),
      ],
      standings: [
        TournamentStandingGroup(
          rows: [
            _standing(name: 'Đội A', points: 4),
            _standing(name: 'Đội B', points: 2),
          ],
        ),
      ],
    );

    expect(podium.state, TournamentPodiumState.provisional);
    expect(podium.entries.first.label, 'Đội A');
  });
}

TournamentCategory _category(TournamentCategoryFormat format) =>
    TournamentCategory(
      id: 'c1',
      name: 'Đôi nam',
      type: 'MEN_DOUBLES',
      registrationMode: TournamentRegistrationMode.team,
      format: format,
      registrationCount: 4,
    );

TournamentMatch _match({
  required String id,
  required TournamentMatchStatus status,
  String? groupId,
  DateTime? startTime,
}) => TournamentMatch(
  id: id,
  categoryId: 'c1',
  groupId: groupId,
  round: '1',
  matchNumber: 1,
  status: status,
  startTime: startTime,
  participants: const [],
);

TournamentMatch _finishedMatch({
  required String id,
  required String round,
  required String side1,
  required String side2,
  required String winnerId,
}) => TournamentMatch(
  id: id,
  categoryId: 'c1',
  round: round,
  matchNumber: 1,
  status: TournamentMatchStatus.finished,
  winnerId: winnerId,
  participants: [
    TournamentMatchParticipant(
      position: 1,
      registrationId: 'r1',
      registration: TournamentRegistration(id: 'r1', pairName: side1),
    ),
    TournamentMatchParticipant(
      position: 2,
      registrationId: 'r2',
      registration: TournamentRegistration(id: 'r2', pairName: side2),
    ),
  ],
);

TournamentStanding _standing({required String name, required int points}) =>
    TournamentStanding(
      registration: TournamentRegistration(id: name, pairName: name),
      matchesPlayed: 1,
      matchesWon: points > 2 ? 1 : 0,
      matchesLost: points > 2 ? 0 : 1,
      matchesDrawn: 0,
      matchesForfeited: 0,
      matchesCancelled: 0,
      points: points,
      pointsFor: points * 10,
      pointDifference: points,
    );
