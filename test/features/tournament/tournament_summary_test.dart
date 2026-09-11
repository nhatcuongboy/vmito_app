import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

void main() {
  test('parses the browse subset and its primary venue', () {
    final tournament = TournamentSummary.fromJson({
      'id': 't1',
      'slug': 'giai-mua-he',
      'name': 'Giải mùa hè',
      'startDate': '2026-08-15T01:00:00.000Z',
      'endDate': '2026-08-16T10:00:00.000Z',
      'status': 'IN_PROGRESS',
      'isPublished': true,
      'isFavorite': true,
      'tournamentVenues': [
        {
          'isPrimary': true,
          'venue': {
            'name': 'Sân Vmito',
            'newCity': 'Hồ Chí Minh',
            'lat': 10.7769,
            'lng': 106.7009,
            'coverPhoto': 'https://example.com/venue.jpg',
          },
        },
      ],
    });

    expect(tournament.id, 't1');
    expect(tournament.status, TournamentStatus.inProgress);
    expect(tournament.location, 'Sân Vmito · Hồ Chí Minh');
    expect(tournament.coverPhoto, 'https://example.com/venue.jpg');
    expect(tournament.venueLatitude, 10.7769);
    expect(tournament.venueLongitude, 106.7009);
    expect(tournament.hasVenueCoordinates, isTrue);
    expect(tournament.isFavorite, isTrue);
  });

  test('parses the host-list fields from GET /tournaments/my', () {
    final tournament = TournamentSummary.fromJson({
      'id': 't2',
      'name': 'Giải nháp',
      'hostId': 'host-1',
      'startDate': '2026-06-06T00:00:00.000Z',
      'endDate': '2026-06-07T00:00:00.000Z',
      'createdAt': '2026-05-01T08:30:00.000Z',
      'status': 'PREPARING',
      'isPublished': false,
      '_count': {'categories': 2, 'players': 10, 'pairs': 5},
    });

    expect(tournament.hostId, 'host-1');
    expect(tournament.categoryCount, 2);
    expect(tournament.createdAt, DateTime.utc(2026, 5, 1, 8, 30));
    expect(tournament.isPublished, isFalse);
  });

  test('defaults the category count when _count is absent', () {
    final tournament = TournamentSummary.fromJson({
      'id': 't3',
      'name': 'Giải',
      'startDate': '2026-06-06T00:00:00.000Z',
      'endDate': '2026-06-06T00:00:00.000Z',
    });

    expect(tournament.categoryCount, 0);
    expect(tournament.createdAt, isNull);
  });

  group('isOverdue', () {
    TournamentSummary tournament(TournamentStatus status) => TournamentSummary(
      id: 't',
      name: 'Giải',
      startDate: DateTime.utc(2026, 6, 5),
      endDate: DateTime.utc(2026, 6, 6),
      status: status,
      isPublished: true,
    );

    test('is false through the whole last day in Vietnam', () {
      // 16:59 UTC on 6 June is 23:59 in Vietnam — still the last day.
      expect(
        tournament(
          TournamentStatus.inProgress,
        ).isOverdue(now: DateTime.utc(2026, 6, 6, 16, 59)),
        isFalse,
      );
    });

    test('turns true at midnight Vietnam time, before UTC catches up', () {
      // 17:00 UTC on 6 June is already 7 June in Vietnam.
      expect(
        tournament(
          TournamentStatus.inProgress,
        ).isOverdue(now: DateTime.utc(2026, 6, 6, 17)),
        isTrue,
      );
    });

    test('only applies to IN_PROGRESS tournaments', () {
      final later = DateTime.utc(2026, 7);
      for (final status in [
        TournamentStatus.preparing,
        TournamentStatus.finished,
        TournamentStatus.cancelled,
      ]) {
        expect(tournament(status).isOverdue(now: later), isFalse);
      }
    });
  });
}
