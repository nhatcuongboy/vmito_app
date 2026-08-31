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
  });
}
