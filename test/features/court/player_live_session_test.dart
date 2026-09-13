import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/court/domain/player_live_session.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  test('derives waiting position from longest-wait-first queue', () {
    const current = SessionPlayer(
      id: 'p1',
      userId: 'u1',
      currentWaitTime: 10,
    );
    const session = Session(
      id: 's1',
      name: 'Live',
      status: SessionStatus.inProgress,
      players: [
        current,
        SessionPlayer(
          id: 'p2',
          currentWaitTime: 20,
        ),
        SessionPlayer(
          id: 'p3',
          status: PlayerStatus.ready,
          currentWaitTime: 40,
        ),
      ],
    );

    const view = PlayerLiveSession(session: session, player: current);

    expect(view.waitingPosition, 2);
  });
}
