import 'dart:async';

/// Emits once per wall-clock minute, aligned to [anchor].
///
/// Ports `useElapsedMinuteTicker` from `vmito-fe/src/hooks/`.
///
/// **The first delay is short on purpose.** A plain 60-second period started at
/// a random moment would flip "12p" to "13p" up to 59 seconds late; two courts
/// started seconds apart would also tick at visibly different times. Waiting
/// only the remainder of the current minute puts every ticker on the same beat
/// as the elapsed value it is displaying.
Stream<int> minuteTicker(DateTime anchor, {DateTime Function()? now}) async* {
  final clock = now ?? DateTime.now;

  int elapsedMinutes() {
    final elapsed = clock().difference(anchor);
    return elapsed.isNegative ? 0 : elapsed.inMinutes;
  }

  yield elapsedMinutes();

  final sinceAnchor = clock().difference(anchor);
  // A clock skew that puts the anchor in the future would make the remainder
  // negative; start the cadence immediately instead of never.
  final intoMinute = sinceAnchor.isNegative
      ? Duration.zero
      : Duration(microseconds: sinceAnchor.inMicroseconds % _minute.inMicroseconds);
  await Future<void>.delayed(_minute - intoMinute);
  yield elapsedMinutes();

  yield* Stream<void>.periodic(_minute).map((_) => elapsedMinutes());
}

const _minute = Duration(minutes: 1);
