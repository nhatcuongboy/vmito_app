import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/utils/minute_ticker.dart';

void main() {
  test('emits the current elapsed minutes immediately', () {
    fakeAsync((async) {
      final now = DateTime(2026, 8, 3, 20, 0, 40);
      final emitted = <int>[];
      minuteTicker(
        now.subtract(const Duration(minutes: 12, seconds: 20)),
        now: () => now,
      ).listen(emitted.add);

      async.flushMicrotasks();
      expect(emitted, [12]);
    });
  });

  // The whole reason this is not a plain `Stream.periodic`: a match started at
  // :40 past the minute must roll over 20 seconds later, not 60.
  test('the first tick lands on the next minute boundary, not 60s later', () {
    fakeAsync((async) {
      var now = DateTime(2026, 8, 3, 20, 0, 40);
      final start = DateTime(2026, 8, 3, 20);
      final emitted = <int>[];
      minuteTicker(start, now: () => now).listen(emitted.add);

      async.flushMicrotasks();
      expect(emitted, [0]);

      // 19 seconds in: still the same minute, nothing new.
      now = now.add(const Duration(seconds: 19));
      async.elapse(const Duration(seconds: 19));
      expect(emitted, [0]);

      // Crossing the boundary at :00 emits.
      now = now.add(const Duration(seconds: 1));
      async.elapse(const Duration(seconds: 1));
      expect(emitted, [0, 1]);
    });
  });

  test('then ticks once a minute', () {
    fakeAsync((async) {
      var now = DateTime(2026, 8, 3, 20);
      final emitted = <int>[];
      minuteTicker(now, now: () => now).listen(emitted.add);

      async.flushMicrotasks();
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(minutes: 1));
        async.elapse(const Duration(minutes: 1));
      }

      expect(emitted, [0, 1, 2, 3]);
    });
  });

  // Device clocks drift and the server sets `startTime`. A negative elapsed
  // must read as zero rather than counting backwards.
  test('a start time in the future reads as zero, not a negative', () {
    fakeAsync((async) {
      final now = DateTime(2026, 8, 3, 20);
      final emitted = <int>[];
      minuteTicker(
        now.add(const Duration(minutes: 5)),
        now: () => now,
      ).listen(emitted.add);

      async
        ..flushMicrotasks()
        ..elapse(const Duration(minutes: 1));

      expect(emitted, isNotEmpty);
      expect(emitted, everyElement(0));
    });
  });
}
