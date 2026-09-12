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
        'streetAddress': '12 Đường Mới',
        'locatedWithin': 'Nhà thi đấu A',
      });

      expect(
        venue.addressLabel(showNewAddress: true),
        '12 Đường Mới, Phường Mới, TP mới',
      );
      expect(
        venue.addressLabel(showNewAddress: false),
        'Địa chỉ cũ, Quận cũ, TP cũ',
      );
      expect(venue.streetAddress, '12 Đường Mới');
      expect(venue.locatedWithin, 'Nhà thi đấu A');
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

    test('parses detail amenities and all venue sports', () {
      final venue = Venue.fromJson({
        'id': 'v1',
        'name': 'Phú Nhuận',
        'sportType': 'BADMINTON',
        'sportTypes': ['BADMINTON', 'PICKLEBALL'],
        'hasCarParking': true,
        'hasCanteen': false,
        'wifiName': 'Vmito Guest',
        'wifiPassword': '12345678',
        'bookingPolicy': 'Đặt trước 30 phút.',
      });

      expect(venue.sportTypes, ['BADMINTON', 'PICKLEBALL']);
      expect(venue.hasCarParking, isTrue);
      expect(venue.hasCanteen, isFalse);
      expect(venue.wifiName, 'Vmito Guest');
      expect(venue.wifiPassword, '12345678');
      expect(venue.bookingPolicy, 'Đặt trước 30 phút.');
    });

    test('formats single and multi-sport venue names like the web', () {
      const candidates = {
        'BADMINTON': 'Sân cầu lông Phú Nhuận',
        'PICKLEBALL': 'Sân pickleball Phú Nhuận',
      };

      expect(
        const Venue(
          id: 'badminton',
          name: 'Phú Nhuận',
          sportType: 'BADMINTON',
        ).displayName(
          generic: 'Sân Phú Nhuận',
          bySport: candidates,
          localeName: 'en',
        ),
        'Sân cầu lông Phú Nhuận',
      );
      expect(
        const Venue(
          id: 'multi',
          name: 'Phú Nhuận',
          sportTypes: ['BADMINTON', 'PICKLEBALL'],
        ).displayName(
          generic: 'Sân Phú Nhuận',
          bySport: candidates,
          localeName: 'en',
        ),
        'Sân Phú Nhuận',
      );
    });

    test('does not duplicate an existing venue affix or sport keyword', () {
      const candidates = {'BADMINTON': 'Sân cầu lông Phú Nhuận'};

      for (final name in [
        'Sân Phú Nhuận',
        'CLB Phú Nhuận',
        'Phú Nhuận Badminton',
      ]) {
        expect(
          Venue(id: name, name: name).displayName(
            generic: 'Sân $name',
            bySport: candidates,
            localeName: 'en',
          ),
          name,
        );
      }
    });

    test('filter preserves the position unless explicitly cleared', () {
      const filter = VenueFilter(latitude: 10.7, longitude: 106.6);
      expect(filter.copyWith(keyword: 'abc').latitude, 10.7);
      expect(filter.copyWith(clearLocation: true).latitude, isNull);
    });

    test('venue filter count excludes keyword, sort, city, and district', () {
      const filter = VenueFilter(
        keyword: 'thpt',
        city: 'Hồ Chí Minh',
        district: 'Phú Nhuận',
        sortBy: 'createdAt',
        favoriteOnly: true,
      );

      expect(filter.activeCount, 1);
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
