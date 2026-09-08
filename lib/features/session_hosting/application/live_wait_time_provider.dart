// The family argument is a small immutable record; spelling out the generated
// provider type adds no useful information here.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/utils/minute_ticker.dart';

typedef LiveWaitTime = ({String playerId, int baselineMinutes, bool isRunning});

/// Injectable so minute-boundary behavior stays deterministic in tests.
final liveWaitTimeClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// A server wait-time snapshot that keeps advancing locally once per minute.
///
/// The backend exposes an integer minute count rather than `waitingSince`, so
/// the best client-side anchor is the moment that snapshot is first observed.
/// When a refresh/socket event supplies a different baseline, Riverpod selects
/// a new family instance and the ticker starts from that authoritative value.
///
/// This is display-only. In particular, it does not port the web app's
/// non-idempotent wait-time heartbeat, which could double-count when a host has
/// the web app and mobile app open together.
final liveWaitTimeProvider = StreamProvider.autoDispose
    .family<int, LiveWaitTime>((ref, input) {
      if (!input.isRunning) return Stream.value(input.baselineMinutes);

      final clock = ref.read(liveWaitTimeClockProvider);
      final observedAt = clock();
      return minuteTicker(
        observedAt,
        now: clock,
      ).map((elapsed) => input.baselineMinutes + elapsed);
    });
