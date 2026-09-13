// The family provider's concrete generic type is intentionally inferred;
// spelling it out couples this file to Riverpod's implementation.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';

/// Authoritative wait-time-in-minutes per waiting player id.
///
/// `Session.players[].currentWaitTime` (from `GET /sessions/:id`) is a
/// stored counter that only advances via a heartbeat call this app
/// deliberately doesn't make (see `HostCourtsTab`'s doc comment). This reads
/// `GET /sessions/:id/wait-times` instead, which the backend computes fresh
/// from each player's `waitingSince` timestamp on every call — safe to poll
/// from any number of clients, unlike the heartbeat.
final waitTimeStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>(
      (ref, sessionId) =>
          ref.watch(sessionRepositoryProvider).waitTimeMinutes(sessionId),
    );
