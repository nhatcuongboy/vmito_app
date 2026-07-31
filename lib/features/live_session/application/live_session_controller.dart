// The family provider's concrete generic type is intentionally inferred;
// spelling it out couples this file to Riverpod's implementation.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';

/// Connection status used by the live screen's reconnecting banner.
final socketConnectionProvider = StreamProvider<bool>((ref) async* {
  final client = ref.watch(socketClientProvider)..connect();
  yield client.isConnected;
  yield* client.connectionState;
});

/// Keeps one live-session REST resource fresh from socket hints.
///
/// Socket payloads are deliberately not treated as authoritative. Events are
/// coalesced, then the session is fetched again from REST; this also makes
/// replayed or out-of-order events harmless.
final liveSessionRealtimeProvider = Provider.autoDispose.family<void, String>((
  ref,
  sessionId,
) {
  final client = ref.watch(socketClientProvider)
    ..connect()
    ..joinSession(sessionId);

  Timer? debounce;
  final subscription = client.events
      .where((event) => _refreshEvents.contains(event.name))
      .where((event) {
        final eventSessionId = event.data['sessionId'];
        return eventSessionId == null || eventSessionId == sessionId;
      })
      .listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(milliseconds: 250), () {
          ref.invalidate(sessionDetailProvider(sessionId));
        });
      });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(subscription.cancel());
    client.leaveSession(sessionId);
  });
});

const _refreshEvents = <String>{
  SessionEvent.sessionUpdated,
  SessionEvent.sessionStarted,
  SessionEvent.sessionCancelled,
  SessionEvent.playerCreated,
  SessionEvent.playerUpdated,
  SessionEvent.playerRemoved,
  SessionEvent.courtUpdated,
  SessionEvent.matchStarted,
  SessionEvent.matchEnded,
  SessionEvent.playersSelected,
  SessionEvent.playersDeselected,
};
