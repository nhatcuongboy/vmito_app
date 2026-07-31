import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

CreateSessionRequest _request({
  String name = 'Kèo tối thứ 6',
  String? description,
  String? location,
  DateTime? startTime,
  List<int> requiredLevels = const [],
  SessionFeeConfig? feeConfig,
  String? hostPhone,
}) => CreateSessionRequest(
  name: name,
  numberOfCourts: 2,
  maxPlayersPerCourt: 8,
  sessionDuration: 120,
  description: description,
  location: location,
  startTime: startTime,
  requiredLevels: requiredLevels,
  feeConfig: feeConfig,
  hostPhone: hostPhone,
);

void main() {
  group('required fields', () {
    test('are always present', () {
      final json = _request().toJson();

      expect(json['name'], 'Kèo tối thứ 6');
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

    test('the name is trimmed', () {
      expect(_request(name: '  Kèo tối  ').toJson()['name'], 'Kèo tối');
    });
  });

  group('optional fields', () {
    test('are omitted rather than sent as null', () {
      // An explicit null would overwrite a backend default; an absent key
      // leaves it alone.
      final json = _request().toJson();

      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('location'), isFalse);
      expect(json.containsKey('startTime'), isFalse);
      expect(json.containsKey('feeConfig'), isFalse);
      expect(json.containsKey('hostPhone'), isFalse);
    });

    test('blank strings count as absent', () {
      final json = _request(location: '   ', description: '').toJson();

      expect(json.containsKey('location'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('present values are trimmed and included', () {
      final json = _request(location: '  18B Cộng Hòa ').toJson();

      expect(json['location'], '18B Cộng Hòa');
    });
  });

  group('startTime', () {
    test('is converted to UTC ISO-8601', () {
      // The form collects local wall time; the API speaks UTC. Sending local
      // time would shift every session by the device's offset.
      final local = DateTime(2026, 7, 10, 18, 30);
      final json = _request(startTime: local).toJson();

      expect(json['startTime'], endsWith('Z'));
      expect(
        DateTime.parse(json['startTime'] as String).toLocal(),
        local,
      );
    });
  });

  group('requiredLevels', () {
    test('an empty list is omitted — "all levels welcome"', () {
      // Sending [] could read as "no level is acceptable". Absence is the
      // documented way to say there is no restriction.
      expect(_request().toJson().containsKey('requiredLevels'), isFalse);
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

    test('maps the split-evenly type', () {
      final json = _request(
        feeConfig: const SessionFeeConfig(feeType: FeeType.splitEvenly),
      ).toJson();

      expect((json['feeConfig']! as Map)['feeType'], 'SPLIT_EVENLY');
    });
  });
}
