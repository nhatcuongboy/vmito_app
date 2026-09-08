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
Stream<int> minuteTicker(DateTime anchor, {DateTime Function()? now}) {
  final clock = now ?? DateTime.now;
  Timer? timer;

  int elapsedMinutes() {
    final elapsed = clock().difference(anchor);
    return elapsed.isNegative ? 0 : elapsed.inMinutes;
  }

  late final StreamController<int> controller;
  controller = StreamController<int>(
    sync: true,
    onListen: () {
      controller.add(elapsedMinutes());

      final sinceAnchor = clock().difference(anchor);
      // A clock skew that puts the anchor in the future would make the
      // remainder negative; start the cadence immediately instead of never.
      final intoMinute = sinceAnchor.isNegative
          ? Duration.zero
          : Duration(
              microseconds: sinceAnchor.inMicroseconds % _minute.inMicroseconds,
            );
      timer = Timer(_minute - intoMinute, () {
        controller.add(elapsedMinutes());
        timer = Timer.periodic(
          _minute,
          (_) => controller.add(elapsedMinutes()),
        );
      });
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
    },
  );
  return controller.stream;
}

const _minute = Duration(minutes: 1);
