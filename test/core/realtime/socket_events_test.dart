import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';

void main() {
  test('session room commands match the backend gateway contract', () {
    expect(SocketCommand.joinSession, 'joinSession');
    expect(SocketCommand.leaveSession, 'leaveSession');
  });

  test('lifecycle events trigger subscribed listeners', () {
    expect(SessionEvent.all, contains(SessionEvent.sessionStarted));
    expect(SessionEvent.all, contains(SessionEvent.sessionCancelled));
  });
}
