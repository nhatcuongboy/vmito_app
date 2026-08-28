import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_map_location.dart';

void main() {
  group('groupSessionsByMapLocation', () {
    test('groups sessions that share a linked venue', () {
      final groups = groupSessionsByMapLocation([
        _session(
          id: 'session-1',
          venue: const SessionVenue(
            id: 'venue-1',
            name: 'Sân A',
            address: 'Quận 1',
            lat: 10.77,
            lng: 106.69,
          ),
        ),
        _session(
          id: 'session-2',
          venue: const SessionVenue(
            id: 'venue-1',
            name: 'Sân A',
            address: 'Quận 1',
            lat: 10.77,
            lng: 106.69,
          ),
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.key, 'venue:venue-1');
      expect(groups.single.sessions.map((item) => item.id), [
        'session-1',
        'session-2',
      ]);
    });

    test('keeps custom locations separate and skips missing coordinates', () {
      final groups = groupSessionsByMapLocation([
        _session(
          id: 'custom-1',
          customLocationName: 'Nhà thi đấu B',
          customLocationLat: 10.8,
          customLocationLng: 106.7,
        ),
        _session(id: 'no-coordinates'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.key, 'custom:custom-1');
      expect(groups.single.name, 'Nhà thi đấu B');
    });

    test('prefers a linked venue over custom coordinates', () {
      final groups = groupSessionsByMapLocation([
        _session(
          id: 'session-1',
          venue: const SessionVenue(
            id: 'venue-1',
            name: 'Sân A',
            lat: 10.77,
            lng: 106.69,
          ),
          customLocationName: 'Địa điểm cũ',
          customLocationLat: 11,
          customLocationLng: 107,
        ),
      ]);

      expect(groups.single.key, 'venue:venue-1');
      expect(groups.single.latitude, 10.77);
    });
  });
}

Session _session({
  required String id,
  SessionVenue? venue,
  String? customLocationName,
  double? customLocationLat,
  double? customLocationLng,
}) => Session(
  id: id,
  name: 'Kèo $id',
  status: SessionStatus.preparing,
  venue: venue,
  customLocationName: customLocationName,
  customLocationLat: customLocationLat,
  customLocationLng: customLocationLng,
);
