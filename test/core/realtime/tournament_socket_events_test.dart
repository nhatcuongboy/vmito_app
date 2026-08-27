import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';

void main() {
  test('tournament room commands match the backend gateway contract', () {
    expect(SocketCommand.joinTournament, 'joinTournament');
    expect(SocketCommand.leaveTournament, 'leaveTournament');
  });

  test('observes every public tournament refresh hint', () {
    expect(
      TournamentEvent.all,
      containsAll([
        TournamentEvent.matchStarted,
        TournamentEvent.scoreUpdated,
        TournamentEvent.matchEnded,
        TournamentEvent.scheduleUpdated,
        TournamentEvent.ended,
      ]),
    );
  });
}
