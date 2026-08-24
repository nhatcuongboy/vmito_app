import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  test('parses a grouped request with multiple player statuses', () {
    final request = MyJoinRequest.fromJson({
      'requestedAt': '2026-08-06T03:00:00.000Z',
      'session': {
        'id': 's1',
        'name': 'Kèo mẫu sân Be Quang Trung',
        'startTime': '2026-08-29T03:00:00.000Z',
        'location': 'Sân Cầu Lông',
        'venue': {'name': 'Be Badminton'},
        'players': [
          {
            'id': 'p1',
            'name': 'Nhật Cường',
            'playerNumber': 1,
            'level': 1,
            'registrationStatus': 'APPROVED',
          },
          {
            'id': 'p2',
            'playerNumber': 2,
            'registrationStatus': 'PENDING',
          },
          {
            'id': 'p3',
            'name': 'Rejected',
            'playerNumber': 3,
            'registrationStatus': 'REJECTED',
          },
        ],
      },
    });

    expect(request.session.id, 's1');
    expect(request.session.locationLabel, 'Be Badminton');
    expect(request.players, hasLength(3));
    expect(
      request.players.map((player) => player.registrationStatus),
      [
        RegistrationStatus.approved,
        RegistrationStatus.pending,
        RegistrationStatus.rejected,
      ],
    );
    expect(request.hasPending, isTrue);
    expect(request.requestedAt, isNotNull);
  });

  test('falls back safely for missing nested fields', () {
    final request = MyJoinRequest.fromJson(
      <String, dynamic>{'session': <String, dynamic>{}},
    );

    expect(request.session.id, isEmpty);
    expect(request.session.locationLabel, isNull);
    expect(request.players, isEmpty);
    expect(request.hasPending, isFalse);
  });
}
