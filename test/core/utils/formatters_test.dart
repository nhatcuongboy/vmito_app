import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vmito_app/core/utils/formatters.dart';

void main() {
  setUpAll(initializeDateFormatting);

  group('Money.vnd', () {
    test('renders whole dong with no decimals', () {
      // VND has no minor unit and the backend sends integers. "90.000,00 ₫"
      // would be wrong, and `'$amount'` on a generated DTO gives "90000.0".
      expect(Money.vnd(90000), contains('90.000'));
      expect(Money.vnd(90000), isNot(contains(',00')));
      expect(Money.vnd(90000), isNot(contains('.0 ')));
    });

    test('groups thousands', () {
      expect(Money.vnd(1500000), contains('1.500.000'));
    });

    test('rounds a double from a generated DTO rather than printing it', () {
      // Numeric fields decode as double because the OpenAPI document has no
      // `type: integer` anywhere. Formatting must not leak that.
      expect(Money.vnd(90000.0), Money.vnd(90000));
      expect(Money.vnd(90000.4), Money.vnd(90000));
    });

    test('handles zero and small amounts', () {
      expect(Money.vnd(0), contains('0'));
      expect(Money.vndPlain(5000), '5.000');
    });
  });

  group('Money.compactVnd', () {
    test('uses k for thousands and tr for millions', () {
      expect(Money.compactVnd(50000), '50k');
      expect(Money.compactVnd(90000), '90k');
      expect(Money.compactVnd(1000000), '1tr');
      expect(Money.compactVnd(1500000), '1,5tr');
    });

    test('falls back to grouped digits when k would lose precision', () {
      // 50.500 is not a whole number of thousands, so "50k" would be a lie.
      expect(Money.compactVnd(50500), '50.500');
    });
  });

  group('Money.compactRange', () {
    test('collapses an equal pair to one value', () {
      expect(Money.compactRange(50000, 50000), '50k');
    });

    test('orders the range regardless of argument order', () {
      expect(Money.compactRange(60000, 50000), '50k-60k');
      expect(Money.compactRange(50000, 60000), '50k-60k');
    });

    test('tolerates a missing side', () {
      expect(Money.compactRange(50000, null), '50k');
      expect(Money.compactRange(null, 60000), '60k');
      expect(Money.compactRange(null, null), isNull);
    });
  });

  group('Dates.relativeDay', () {
    final now = DateTime(2026, 7, 10, 12);

    test('names today, tomorrow and yesterday', () {
      expect(Dates.relativeDay(DateTime(2026, 7, 10, 8), now: now), 'Hôm nay');
      expect(Dates.relativeDay(DateTime(2026, 7, 11, 8), now: now), 'Ngày mai');
      expect(Dates.relativeDay(DateTime(2026, 7, 9, 23), now: now), 'Hôm qua');
    });

    test('compares calendar days, not elapsed hours', () {
      // 23:00 today and 01:00 tomorrow are two hours apart but different days.
      expect(Dates.relativeDay(DateTime(2026, 7, 10, 23), now: now), 'Hôm nay');
      expect(Dates.relativeDay(DateTime(2026, 7, 11, 1), now: now), 'Ngày mai');
    });

    test('falls back to a date further out', () {
      expect(
        Dates.relativeDay(DateTime(2026, 7, 20, 8), now: now),
        contains('thg 7'),
      );
    });
  });

  group('Dates.dayWithRange', () {
    test('renders a start-end range', () {
      final now = DateTime(2026, 7, 10, 12);
      final label = Dates.dayWithRange(
        DateTime(2026, 7, 10, 8),
        DateTime(2026, 7, 10, 10),
        now: now,
      );

      expect(label, 'Hôm nay, 08:00-10:00');
    });

    test('renders only the start when there is no end', () {
      final now = DateTime(2026, 7, 10, 12);
      expect(
        Dates.dayWithRange(DateTime(2026, 7, 10, 8), null, now: now),
        'Hôm nay, 08:00',
      );
    });
  });

  group('Dates.waitMinutes', () {
    test('formats minutes, hours, and the exact-hour case', () {
      expect(Dates.waitMinutes(0), '0p');
      expect(Dates.waitMinutes(45), '45p');
      expect(Dates.waitMinutes(60), '1g');
      expect(Dates.waitMinutes(80), '1g 20p');
      expect(Dates.waitMinutes(125), '2g 5p');
    });
  });

  group('Dates.dayAndTime', () {
    test('uses Vietnamese month names', () {
      final time = DateTime.utc(2026, 7, 10, 14);

      // Rendered in the device zone, so assert on the parts that do not move
      // with it.
      expect(Dates.dayAndTime(time), contains('thg 7'));
      expect(Dates.dayAndTime(time), contains('•'));
    });
  });
}
