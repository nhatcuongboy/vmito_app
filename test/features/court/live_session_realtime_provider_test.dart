import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';

class _MockSocketClient extends Mock implements SocketClient {}

void main() {
  test('ignores another session and debounces a same-session burst', () async {
    final socket = _MockSocketClient();
    final events = StreamController<SocketEvent>.broadcast();
    addTearDown(events.close);
    when(() => socket.events).thenAnswer((_) => events.stream);
    when(socket.connect).thenAnswer((_) {});
    when(() => socket.joinSession(any())).thenAnswer((_) {});
    when(() => socket.leaveSession(any())).thenAnswer((_) {});
    var sessionLoads = 0;
    var matchLoads = 0;
    final container = ProviderContainer(
      overrides: [
        socketClientProvider.overrideWithValue(socket),
        sessionDetailProvider.overrideWith((_, _) async {
          sessionLoads++;
          return const Session(
            id: 's1',
            name: 'Live',
            status: SessionStatus.inProgress,
          );
        }),
        matchHistoryProvider.overrideWith((_, _) async {
          matchLoads++;
          return const [];
        }),
      ],
    );
    addTearDown(container.dispose);
    final sessionSubscription = container.listen(
      sessionDetailProvider('s1'),
      (_, _) {},
      fireImmediately: true,
    );
    final matchSubscription = container.listen(
      matchHistoryProvider('s1'),
      (_, _) {},
      fireImmediately: true,
    );
    final realtimeSubscription = container.listen(
      liveSessionRealtimeProvider('s1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(sessionSubscription.close);
    addTearDown(matchSubscription.close);
    addTearDown(realtimeSubscription.close);
    await container.read(sessionDetailProvider('s1').future);
    await container.read(matchHistoryProvider('s1').future);

    events.add(
      const SocketEvent(SessionEvent.playerUpdated, {'sessionId': 's2'}),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect((sessionLoads, matchLoads), (1, 1));

    for (var index = 0; index < 4; index++) {
      events.add(
        const SocketEvent(SessionEvent.courtUpdated, {'sessionId': 's1'}),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await container.read(sessionDetailProvider('s1').future);
    await container.read(matchHistoryProvider('s1').future);
    expect((sessionLoads, matchLoads), (2, 2));
  });
}
