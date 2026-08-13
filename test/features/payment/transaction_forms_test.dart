import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/payment/domain/form/transaction_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

void main() {
  group('resolveFinanceQuery', () {
    test('uses UTC calendar boundaries and day granularity for this month', () {
      final query = resolveFinanceQuery(
        period: FinancePeriod.thisMonth,
        now: DateTime.utc(2026, 8, 13, 4),
      );

      expect(query.from, DateTime.utc(2026, 8));
      expect(query.to, DateTime.utc(2026, 8, 13, 23, 59, 59, 999));
      expect(query.granularity, HostFinanceGranularity.day);
    });

    test('selects weekly and monthly granularity by range size', () {
      final weekly = resolveFinanceQuery(
        period: FinancePeriod.custom,
        now: DateTime.utc(2026),
        customFrom: DateTime(2026),
        customTo: DateTime(2026, 3),
      );
      final monthly = resolveFinanceQuery(
        period: FinancePeriod.custom,
        now: DateTime.utc(2026),
        customFrom: DateTime(2025),
        customTo: DateTime(2026),
      );

      expect(weekly.granularity, HostFinanceGranularity.week);
      expect(monthly.granularity, HostFinanceGranularity.month);
    });
  });

  group('finance form validation', () {
    test('rejects reversed and overlong custom ranges', () {
      final form = createFinanceFilterForm();
      addTearDown(form.dispose);
      form.patchValue({
        FinanceFilterControl.period: FinancePeriod.custom,
        FinanceFilterControl.from: DateTime(2026, 2),
        FinanceFilterControl.to: DateTime(2026),
      });
      expect(form.hasError('rangeOrder'), isTrue);

      form.patchValue({
        FinanceFilterControl.from: DateTime(2020),
        FinanceFilterControl.to: DateTime(2023),
      });
      expect(form.hasError('rangeTooLong'), isTrue);
    });
  });

  test('percentDelta mirrors web zero-baseline behavior', () {
    expect(percentDelta(0, 0), 0);
    expect(percentDelta(10, 0), isNull);
    expect(percentDelta(150, 100), 50);
  });

  test('filters and sorts player summaries', () {
    const players = [
      HostTransactionSummary(
        userId: '1',
        userName: 'An',
        totalSessions: 2,
        totalAmount: 200,
        paidAmount: 100,
        pendingAmount: 100,
      ),
      HostTransactionSummary(
        userId: '2',
        userName: 'Bình',
        totalSessions: 4,
        totalAmount: 300,
        paidAmount: 300,
        pendingAmount: 0,
      ),
    ];

    final result = filterFinancePlayers(
      players,
      search: 'an',
      status: PlayerPaymentStatusFilter.pending,
      sort: PlayerFinanceSort.totalAmount,
    );

    expect(result.map((item) => item.userId), ['1']);
  });
}
