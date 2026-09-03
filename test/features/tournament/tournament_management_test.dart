import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';

void main() {
  test('access maps permissions and grants host/admin every scope', () {
    final manager = TournamentMyAccess.fromJson({
      'tournamentId': 't1',
      'isHost': false,
      'isAdmin': false,
      'permissions': ['SCHEDULE', 'RESULTS', 'UNKNOWN'],
    });
    const host = TournamentMyAccess(
      tournamentId: 't1',
      isHost: true,
      isAdmin: false,
      permissions: {},
    );

    expect(manager.canManage, isTrue);
    expect(manager.allows(TournamentPermission.schedule), isTrue);
    expect(manager.allows(TournamentPermission.participants), isFalse);
    expect(host.allows(TournamentPermission.participants), isTrue);
  });

  test('manager maps its user and ignores unknown permissions', () {
    final manager = TournamentManager.fromJson({
      'id': 'm1',
      'tournamentId': 't1',
      'userId': 'u1',
      'permissions': ['PARTICIPANTS', 'BAD_VALUE'],
      'user': {'id': 'u1', 'name': 'An', 'email': 'an@example.com'},
    });

    expect(manager.user?.name, 'An');
    expect(manager.permissions, {TournamentPermission.participants});
  });
}
