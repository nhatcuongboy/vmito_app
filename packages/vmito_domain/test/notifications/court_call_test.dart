import 'package:test/test.dart';
import 'package:vmito_domain/vmito_domain.dart';

void main() {
  group('CourtCall.tryParse', () {
    test('parses the web/backend players_selected payload', () {
      final call = CourtCall.tryParse({
        'userId': 'user-1',
        'sessionId': 'session-1',
        'courtId': 'court-2',
        'courtName': 'Center Court',
        'courtNumber': 2,
      });

      expect(call, isNotNull);
      expect(call!.courtNumber, 2);
      expect(call.fingerprint, 'user-1:session-1:court-2');
    });

    test('accepts a numeric string and rejects incomplete payloads', () {
      expect(
        CourtCall.tryParse({
          'userId': 'user-1',
          'sessionId': 'session-1',
          'courtNumber': '3',
        })?.courtNumber,
        3,
      );
      expect(
        CourtCall.tryParse({'sessionId': 'session-1', 'courtNumber': 3}),
        isNull,
      );
    });
  });
}
