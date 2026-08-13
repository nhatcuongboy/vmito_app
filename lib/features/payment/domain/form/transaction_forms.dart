import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

enum FinancePeriod { thisMonth, lastMonth, quarter, year, custom }

enum SessionFinanceSort { date, netActual, income, outstanding }

enum PlayerPaymentStatusFilter { all, pending, paid }

enum PlayerFinanceSort { totalAmount, pendingAmount, name, sessions }

abstract final class FinanceFilterControl {
  static const period = 'period';
  static const from = 'from';
  static const to = 'to';
}

abstract final class PlayerFilterControl {
  static const search = 'search';
  static const status = 'status';
  static const sort = 'sort';
}

abstract final class PaymentReviewControl {
  static const amount = 'amount';
  static const method = 'method';
  static const notes = 'notes';
}

const maxFinanceRangeDays = 730;

FormGroup createFinanceFilterForm() => FormGroup(
  {
    FinanceFilterControl.period: FormControl<FinancePeriod>(
      value: FinancePeriod.thisMonth,
      validators: [Validators.required],
    ),
    FinanceFilterControl.from: FormControl<DateTime>(),
    FinanceFilterControl.to: FormControl<DateTime>(),
  },
  validators: [Validators.delegate(validateFinanceRange)],
);

FormGroup createPlayerFinanceFilterForm() => FormGroup({
  PlayerFilterControl.search: FormControl<String>(value: ''),
  PlayerFilterControl.status: FormControl<PlayerPaymentStatusFilter>(
    value: PlayerPaymentStatusFilter.all,
  ),
  PlayerFilterControl.sort: FormControl<PlayerFinanceSort>(
    value: PlayerFinanceSort.totalAmount,
  ),
});

FormGroup createPaymentReviewForm(PaymentRecord payment) => FormGroup({
  PaymentReviewControl.amount: FormControl<int>(
    value: payment.amount,
    validators: [Validators.required, Validators.min(0)],
  ),
  PaymentReviewControl.method: FormControl<PaymentMethod>(
    value: payment.paymentMethod,
  ),
  PaymentReviewControl.notes: FormControl<String>(
    value: payment.hostNotes ?? '',
  ),
});

Map<String, dynamic>? validateFinanceRange(AbstractControl<dynamic> control) {
  final group = control as FormGroup;
  final period = group.control(FinanceFilterControl.period).value;
  if (period != FinancePeriod.custom) return null;
  final from = group.control(FinanceFilterControl.from).value as DateTime?;
  final to = group.control(FinanceFilterControl.to).value as DateTime?;
  if (from == null || to == null) return {'rangeRequired': true};
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  if (start.isAfter(end)) return {'rangeOrder': true};
  if (end.difference(start).inDays + 1 > maxFinanceRangeDays) {
    return {'rangeTooLong': true};
  }
  return null;
}

HostFinanceQuery resolveFinanceQuery({
  required FinancePeriod period,
  required DateTime now,
  DateTime? customFrom,
  DateTime? customTo,
}) {
  final utcNow = now.toUtc();
  late DateTime from;
  late DateTime to;
  switch (period) {
    case FinancePeriod.thisMonth:
      from = DateTime.utc(utcNow.year, utcNow.month);
      to = _endOfUtcDay(utcNow);
    case FinancePeriod.lastMonth:
      from = DateTime.utc(utcNow.year, utcNow.month - 1);
      to = DateTime.utc(
        utcNow.year,
        utcNow.month,
      ).subtract(const Duration(milliseconds: 1));
    case FinancePeriod.quarter:
      final firstMonth = ((utcNow.month - 1) ~/ 3) * 3 + 1;
      from = DateTime.utc(utcNow.year, firstMonth);
      to = _endOfUtcDay(utcNow);
    case FinancePeriod.year:
      from = DateTime.utc(utcNow.year);
      to = _endOfUtcDay(utcNow);
    case FinancePeriod.custom:
      if (customFrom == null || customTo == null) {
        throw ArgumentError('Custom range requires both dates.');
      }
      from = DateTime.utc(customFrom.year, customFrom.month, customFrom.day);
      to = DateTime.utc(
        customTo.year,
        customTo.month,
        customTo.day,
        23,
        59,
        59,
        999,
      );
  }
  final days = to.difference(from).inDays + 1;
  final granularity = days <= 31
      ? HostFinanceGranularity.day
      : days <= 120
      ? HostFinanceGranularity.week
      : HostFinanceGranularity.month;
  return HostFinanceQuery(from: from, to: to, granularity: granularity);
}

DateTime _endOfUtcDay(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
  23,
  59,
  59,
  999,
);

int? percentDelta(num current, num previous) {
  if (previous == 0) return current == 0 ? 0 : null;
  return (((current - previous) / previous.abs()) * 100).round();
}

List<HostFinanceSessionRow> sortFinanceSessions(
  Iterable<HostFinanceSessionRow> rows,
  SessionFinanceSort sort,
) {
  final result = rows.toList();
  switch (sort) {
    case SessionFinanceSort.date:
      result.sort(
        (a, b) => (b.startTime ?? DateTime(0)).compareTo(
          a.startTime ?? DateTime(0),
        ),
      );
    case SessionFinanceSort.netActual:
      result.sort((a, b) => a.netActual.compareTo(b.netActual));
    case SessionFinanceSort.income:
      result.sort((a, b) => b.income.compareTo(a.income));
    case SessionFinanceSort.outstanding:
      result.sort((a, b) => b.outstanding.compareTo(a.outstanding));
  }
  return result;
}

List<HostTransactionSummary> filterFinancePlayers(
  Iterable<HostTransactionSummary> summaries, {
  required String search,
  required PlayerPaymentStatusFilter status,
  required PlayerFinanceSort sort,
}) {
  final query = search.trim().toLowerCase();
  final result = summaries.where((summary) {
    final matchesName = summary.userName.toLowerCase().contains(query);
    final matchesStatus = switch (status) {
      PlayerPaymentStatusFilter.all => true,
      PlayerPaymentStatusFilter.pending => summary.pendingAmount > 0,
      PlayerPaymentStatusFilter.paid => summary.pendingAmount == 0,
    };
    return matchesName && matchesStatus;
  }).toList();
  switch (sort) {
    case PlayerFinanceSort.totalAmount:
      result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    case PlayerFinanceSort.pendingAmount:
      result.sort((a, b) => b.pendingAmount.compareTo(a.pendingAmount));
    case PlayerFinanceSort.name:
      result.sort((a, b) => a.userName.compareTo(b.userName));
    case PlayerFinanceSort.sessions:
      result.sort((a, b) => b.totalSessions.compareTo(a.totalSessions));
  }
  return result;
}
