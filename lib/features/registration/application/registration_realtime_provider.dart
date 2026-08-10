// The family provider's concrete generic type is intentionally inferred;
// spelling it out couples this file to Riverpod's implementation.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/core/realtime/socket_events.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';

/// Keeps the detail screen's registration state fresh while it is open.
///
/// The case this exists for: a player registers, sees "pending", and the host
/// approves on another device. Without this the bar keeps saying "pending"
/// until a pull-to-refresh.
///
/// Same shape as `liveSessionRealtimeProvider` — join the room, debounce, then
/// re-read over REST rather than trusting the payload, so replayed or
/// out-of-order events are harmless.
final registrationRealtimeProvider = Provider.autoDispose.family<void, String>((
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
          ref
            ..invalidate(myRegistrationProvider(sessionId))
            ..invalidate(sessionDetailProvider(sessionId));
        });
      });

  ref.onDispose(() {
    debounce?.cancel();
    unawaited(subscription.cancel());
    client.leaveSession(sessionId);
  });
});

/// `playerCreated` / `playerRemoved` matter too: they move the approved count,
/// which is what decides whether the session reads as full.
const _refreshEvents = <String>{
  SessionEvent.registrationStatusUpdated,
  SessionEvent.playerCreated,
  SessionEvent.playerRemoved,
};
