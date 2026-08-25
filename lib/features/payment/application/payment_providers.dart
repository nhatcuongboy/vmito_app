// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

final paymentLedgerProvider = FutureProvider.family<PaymentLedger, String>(
  (ref, sessionId) => ref.watch(paymentRepositoryProvider).ledger(sessionId),
);

final paymentSettingsProvider = FutureProvider<List<HostPaymentSettings>>(
  (ref) => ref.watch(paymentRepositoryProvider).settings(),
);

final sessionExpensesProvider =
    FutureProvider.family<List<SessionExpense>, String>(
      (ref, sessionId) =>
          ref.watch(paymentRepositoryProvider).expenses(sessionId),
    );

final sessionFeeConfigProvider =
    FutureProvider.family<SessionFeeConfig?, String>(
      (ref, sessionId) =>
          ref.watch(paymentRepositoryProvider).feeConfig(sessionId),
    );

final paymentRemindersProvider = FutureProvider<Map<String, PaymentReminder>>((
  ref,
) async {
  final reminders = await ref
      .watch(paymentRepositoryProvider)
      .remindersForCreator();
  return {
    for (final reminder in reminders)
      for (final paymentId in reminder.paymentIds) paymentId: reminder,
  };
});

final vietnamBanksProvider = FutureProvider<List<VietnamBank>>((ref) async {
  try {
    return await ref.watch(paymentRepositoryProvider).vietnamBanks();
  } on Object {
    return const [];
  }
});

final hostTransactionSummaryProvider =
    FutureProvider<List<HostTransactionSummary>>(
      (ref) => ref.watch(paymentRepositoryProvider).hostSummary(),
    );

final hostUserTransactionsProvider =
    FutureProvider.family<List<PaymentRecord>, String>(
      (ref, userId) =>
          ref.watch(paymentRepositoryProvider).transactionsForUser(userId),
    );

final hostFinanceReportProvider =
    FutureProvider.family<HostFinanceReport, HostFinanceQuery>(
      (ref, query) => ref.watch(paymentRepositoryProvider).financeReport(query),
    );
