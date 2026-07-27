import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/network/api_response.dart';

/// The envelope is applied inconsistently by the backend, so both shapes must
/// keep working — an app release must not be needed when the backend is fixed.
void main() {
  group('unwrap', () {
    test('reads through the {success, data} envelope', () {
      final body = {
        'success': true,
        'data': {'id': 'abc'},
      };

      expect(unwrap(body, (json) => json['id']), 'abc');
    });

    test('passes a bare payload through unchanged', () {
      // /auth/refresh and /auth/register respond without the envelope.
      final body = {'id': 'abc'};

      expect(unwrap(body, (json) => json['id']), 'abc');
    });
  });

  group('unwrapList', () {
    test('reads an enveloped list', () {
      final body = {
        'success': true,
        'data': [
          {'id': '1'},
          {'id': '2'},
        ],
      };

      expect(unwrapList(body, (json) => json['id']), ['1', '2']);
    });

    test('reads a bare list', () {
      final body = [
        {'id': '1'},
      ];

      expect(unwrapList(body, (json) => json['id']), ['1']);
    });

    test('throws when the payload is not a list', () {
      expect(
        () => unwrapList({'id': '1'}, (json) => json['id']),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
