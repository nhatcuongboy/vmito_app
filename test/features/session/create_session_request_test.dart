import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';
import 'package:vmito_app/shared/models/match.dart';

CreateSessionRequest _request({
  String name = 'Kèo tối thứ 6',
  SessionLocationPayload? location,
  String hostName = 'Cường',
  String description = '',
  String? referenceVideoUrl,
  String hostPhone = '',
  String? clubId,
  int? numberOfCourts = 2,
  List<SessionCourtDraft>? courts,
  int? sessionDuration = 120,
  DateTime? startTime,
  DateTime? endTime,
  List<int> requiredLevels = const [],
  SessionFeeConfig? feeConfig,
  MatchType defaultMatchType = MatchType.doubles,
  String shuttlecock = '',
  List<String> images = const [],
}) => CreateSessionRequest(
  name: name,
  location: location ?? const VenueLocation('venue-1'),
  hostName: hostName,
  maxPlayersPerCourt: 8,
  description: description,
  referenceVideoUrl: referenceVideoUrl,
  hostPhone: hostPhone,
  clubId: clubId,
  numberOfCourts: numberOfCourts,
  courts: courts,
  sessionDuration: sessionDuration,
  startTime: startTime,
  endTime: endTime,
  requiredLevels: requiredLevels,
  feeConfig: feeConfig,
  defaultMatchType: defaultMatchType,
  shuttlecock: shuttlecock,
  images: images,
);

void main() {
  group('required fields', () {
    test('are always present', () {
      final json = _request().toJson();

      expect(json['name'], 'Kèo tối thứ 6');
      expect(json['hostName'], 'Cường');
      expect(json['numberOfCourts'], 2);
      expect(json['maxPlayersPerCourt'], 8);
      expect(json['sessionDuration'], 120);
    });

    test('counts are ints, not doubles', () {
      // The generated DTOs decode every number as double because the OpenAPI
      // document has no `type: integer`. Sending 2.0 where the backend expects
      // an int is a class of bug this request type exists to prevent.
      final json = _request().toJson();

      expect(json['numberOfCourts'], isA<int>());
      expect(json['maxPlayersPerCourt'], isA<int>());
      expect(json['sessionDuration'], isA<int>());
    });

    test('the name and host name are trimmed', () {
      final json = _request(name: '  Kèo tối  ', hostName: ' Cường ').toJson();

      expect(json['name'], 'Kèo tối');
      expect(json['hostName'], 'Cường');
    });
  });

  group('clearable fields', () {
    test('are sent explicitly, so an edit can blank them', () {
      // Unlike the fields this request does not collect, these are always
      // present: omitting `description` on a PUT would make it impossible to
      // clear one that was set on web.
      final json = _request().toJson();

      expect(json['description'], '');
      expect(json['hostPhone'], '');
      expect(json['shuttlecock'], '');
      expect(json['referenceVideoUrl'], isNull);
      expect(json['clubId'], isNull);
      expect(json['feeConfig'], isNull);
    });

    test('blank strings normalise to empty or null, never whitespace', () {
      final json = _request(
        description: '   ',
        hostPhone: '  ',
        referenceVideoUrl: '  ',
        clubId: '',
      ).toJson();

      expect(json['description'], '');
      expect(json['hostPhone'], '');
      expect(json['referenceVideoUrl'], isNull);
      expect(json['clubId'], isNull);
    });
  });

  group('location', () {
    test('a venue sends venueId and no customLocation', () {
      final json = _request(location: const VenueLocation('venue-9')).toJson();

      expect(json['locationType'], 'VENUE');
      expect(json['venueId'], 'venue-9');
      expect(json.containsKey('customLocation'), isFalse);
    });

    test('a custom place sends customLocation and no venueId', () {
      final json = _request(
        location: const CustomLocation(
          name: 'Sân Bàu Cát',
          address: ' 18B Cộng Hòa ',
          placeId: 'ChIJabc',
          lat: 10.79,
          lng: 106.65,
        ),
      ).toJson();

      expect(json['locationType'], 'CUSTOM');
      expect(json.containsKey('venueId'), isFalse);

      final custom = json['customLocation']! as Map<String, dynamic>;
      expect(custom['name'], 'Sân Bàu Cát');
      expect(custom['address'], '18B Cộng Hòa');
      expect(custom['placeId'], 'ChIJabc');
      expect(custom['lat'], 10.79);
    });

    test('a typed address carries no placeId or coordinates', () {
      // A stale pin is worse than none: it sends players to the wrong court.
      final json = _request(
        location: const CustomLocation(name: 'Sân trường', address: 'Gò Vấp'),
      ).toJson();
      final custom = json['customLocation']! as Map<String, dynamic>;

      expect(custom.containsKey('placeId'), isFalse);
      expect(custom.containsKey('lat'), isFalse);
      expect(custom.containsKey('lng'), isFalse);
    });
  });

  group('courts and schedule', () {
    test('are omitted when null, so a running session keeps them', () {
      final json = _request(
        numberOfCourts: null,
        sessionDuration: null,
      ).toJson();

      expect(json.containsKey('numberOfCourts'), isFalse);
      expect(json.containsKey('courts'), isFalse);
      expect(json.containsKey('sessionDuration'), isFalse);
      expect(json.containsKey('startTime'), isFalse);
    });

    test('court rows carry a horizontal direction and drop blank names', () {
      final json = _request(
        courts: const [
          SessionCourtDraft(key: 'a', courtNumber: 1, courtName: ' Sân A '),
          SessionCourtDraft(key: 'b', courtNumber: 2),
        ],
      ).toJson();
      final courts = json['courts']! as List<dynamic>;

      expect(courts, hasLength(2));
      expect((courts.first as Map)['courtName'], 'Sân A');
      expect((courts.first as Map)['direction'], 'HORIZONTAL');
      expect((courts.last as Map).containsKey('courtName'), isFalse);
    });

    test('an existing court keeps its id, so its matches survive an edit', () {
      final json = _request(
        courts: const [
          SessionCourtDraft(key: 'a', courtNumber: 1, courtId: 'court-7'),
        ],
      ).toJson();

      expect(((json['courts']! as List).first as Map)['id'], 'court-7');
    });

    test('times are converted to UTC ISO-8601', () {
      // The form collects local wall time; the API speaks UTC. Sending local
      // time would shift every session by the device's offset.
      final local = DateTime(2026, 7, 10, 18, 30);
      final json = _request(startTime: local, endTime: local).toJson();

      expect(json['startTime'], endsWith('Z'));
      expect(DateTime.parse(json['startTime'] as String).toLocal(), local);
    });
  });

  group('requiredLevels', () {
    test('an empty list is sent — it is how a host reopens a session', () {
      // Unlike the old create-only request, this one also serves PUT, where an
      // absent key would leave a previous restriction in place.
      expect(_request().toJson()['requiredLevels'], isEmpty);
    });

    test('a non-empty band is sent verbatim, in the order given', () {
      // Order matters: the picker hands over display order (9, 1, 10), which
      // is not numeric order, and re-sorting here would corrupt the band.
      final json = _request(requiredLevels: [9, 1, 10]).toJson();

      expect(json['requiredLevels'], [9, 1, 10]);
    });
  });

  group('feeConfig', () {
    test('sends integer VND amounts', () {
      final json = _request(
        feeConfig: const SessionFeeConfig(maleFee: 90000, femaleFee: 80000),
      ).toJson();
      final fees = json['feeConfig']! as Map<String, dynamic>;

      expect(fees['feeType'], 'FIXED');
      expect(fees['maleFee'], 90000);
      expect(fees['maleFee'], isA<int>());
      expect(fees['femaleFee'], 80000);
    });

    test('omits a side that was left blank', () {
      final json = _request(
        feeConfig: const SessionFeeConfig(maleFee: 90000),
      ).toJson();
      final fees = json['feeConfig']! as Map<String, dynamic>;

      expect(fees.containsKey('femaleFee'), isFalse);
    });

    test('a split-evenly config carries no fixed prices', () {
      // The per-player number is computed after the session ends; sending the
      // fixed fields alongside SPLIT_EVENLY would show players a price the
      // backend will not honour.
      final json = _request(
        feeConfig: const SessionFeeConfig(
          feeType: FeeType.splitEvenly,
          maleFee: 90000,
        ),
      ).toJson();
      final fees = json['feeConfig']! as Map<String, dynamic>;

      expect(fees['feeType'], 'SPLIT_EVENLY');
      expect(fees.containsKey('maleFee'), isFalse);
    });
  });

  test('the match type is sent as the backend enum', () {
    expect(
      _request(
        defaultMatchType: MatchType.singles,
      ).toJson()['defaultMatchType'],
      'SINGLES',
    );
  });

  test('sport type is sent as the backend enum', () {
    const request = CreateSessionRequest(
      name: 'Pickleball tối',
      sportType: SessionSportType.pickleball,
      location: VenueLocation('venue-1'),
      hostName: 'Cường',
      maxPlayersPerCourt: 8,
    );

    expect(request.toJson()['sportType'], 'PICKLEBALL');
  });
}
