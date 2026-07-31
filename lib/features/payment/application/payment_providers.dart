// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

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

final hostTransactionSummaryProvider =
    FutureProvider<List<HostTransactionSummary>>(
      (ref) => ref.watch(paymentRepositoryProvider).hostSummary(),
    );

final hostUserTransactionsProvider =
    FutureProvider.family<List<PaymentRecord>, String>(
      (ref, userId) =>
          ref.watch(paymentRepositoryProvider).transactionsForUser(userId),
    );
