import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

void main() {
  group('Venue', () {
    test('uses new-era address fields as one consistent address', () {
      final venue = Venue.fromJson({
        'id': 'v1',
        'name': 'Sân A',
        'address': 'Địa chỉ cũ',
        'district': 'Quận cũ',
        'city': 'TP cũ',
        'newAddress': '12 Đường Mới',
        'newDistrict': 'Phường Mới',
        'newCity': 'TP mới',
      });

      expect(venue.addressLabel, '12 Đường Mới, Phường Mới, TP mới');
    });

    test('parses paginated search response and image objects', () {
      final page = VenuePage.fromJson({
        'data': [
          {
            'id': 'v1',
            'name': 'Sân A',
            'coverPhoto': 'cover.jpg',
            'images': [
              'one.jpg',
              {'url': 'two.jpg'},
            ],
          },
        ],
        'pagination': {'page': 2, 'totalPages': 3, 'total': 31},
      });

      expect(page.page, 2);
      expect(page.totalPages, 3);
      expect(page.total, 31);
      expect(page.venues.single.gallery, ['cover.jpg', 'one.jpg', 'two.jpg']);
    });

    test('filter preserves the position unless explicitly cleared', () {
      const filter = VenueFilter(latitude: 10.7, longitude: 106.6);
      expect(filter.copyWith(keyword: 'abc').latitude, 10.7);
      expect(filter.copyWith(clearLocation: true).latitude, isNull);
    });

    test('session venue filter counts once and clears as one unit', () {
      const filters = BrowseSessionFilters(
        venueId: 'venue-1',
        venueName: 'Sân A',
      );

      expect(filters.activeCount, 1);
      expect(filters.copyWith(clearVenue: true).venueId, isNull);
      expect(filters.copyWith(clearVenue: true).venueName, isNull);
    });
  });
}
