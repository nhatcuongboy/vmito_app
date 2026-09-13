import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

import '../../support/fake_secure_storage.dart';

class _MockSocket extends Mock implements io.Socket {}

dynamic _fallbackHandler(dynamic _) {}

void main() {
  setUpAll(() => registerFallbackValue(_fallbackHandler));

  test(
    'ref-counts rooms and rejoins session and current user after connect',
    () {
      final socket = _MockSocket();
      final handlers = <String, dynamic Function(dynamic)>{};
      final emitted = <(String, dynamic)>[];
      var connected = false;
      when(() => socket.connected).thenAnswer((_) => connected);
      when(() => socket.on(any(), any())).thenAnswer((invocation) {
        handlers[invocation.positionalArguments[0] as String] =
            invocation.positionalArguments[1] as dynamic Function(dynamic);
        return () {};
      });
      when(
        () => socket.emit(any<String>(), any<Object>()),
      ).thenAnswer((invocation) {
        emitted.add((
          invocation.positionalArguments[0] as String,
          invocation.positionalArguments[1],
        ));
      });
      when(socket.dispose).thenAnswer((_) {});
      final client = SocketClient(
        tokenStorage: TokenStorage(FakeSecureStorage()),
        observedEvents: const [],
        socketFactory: (_, _) => socket,
      );
      addTearDown(client.dispose);

      client
        ..joinSession('s1')
        ..joinSession('s1')
        ..setAuthenticatedUser('u1');
      expect(emitted, isEmpty);

      connected = true;
      handlers['connect']!(null);
      expect(emitted, contains((SocketCommand.joinSession, 's1')));
      expect(
        emitted,
        contains(
          predicate<(String, dynamic)>(
            (item) =>
                item.$1 == SocketCommand.joinUserRoom &&
                (item.$2 as Map<String, dynamic>)['userId'] == 'u1',
          ),
        ),
      );

      client.leaveSession('s1');
      expect(
        emitted.where((item) => item.$1 == SocketCommand.leaveSession),
        isEmpty,
      );
      client.leaveSession('s1');
      expect(emitted, contains((SocketCommand.leaveSession, 's1')));

      client.joinSession('s2');
      final userJoinCount = emitted
          .where((item) => item.$1 == SocketCommand.joinUserRoom)
          .length;
      client.setAuthenticatedUser(null);
      handlers['connect']!(null);
      expect(
        emitted.where((item) => item.$1 == SocketCommand.joinUserRoom),
        hasLength(userJoinCount),
      );
      expect(
        emitted.where(
          (item) => item.$1 == SocketCommand.joinSession && item.$2 == 's2',
        ),
        hasLength(2),
      );
    },
  );
}
