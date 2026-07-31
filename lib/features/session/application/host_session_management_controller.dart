// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/payment_service.dart';
import 'package:vmito_app/features/session/data/session_service.dart';
import 'package:vmito_app/features/session/domain/payment.dart';

final paymentLedgerProvider = FutureProvider.family<PaymentLedger, String>(
  (ref, sessionId) => ref.watch(paymentServiceProvider).ledger(sessionId),
);

final paymentSettingsProvider = FutureProvider<List<HostPaymentSettings>>(
  (ref) => ref.watch(paymentServiceProvider).settings(),
);

final sessionExpensesProvider =
    FutureProvider.family<List<SessionExpense>, String>(
      (ref, sessionId) => ref.watch(paymentServiceProvider).expenses(sessionId),
    );

final hostTransactionSummaryProvider =
    FutureProvider<List<HostTransactionSummary>>(
      (ref) => ref.watch(paymentServiceProvider).hostSummary(),
    );

final hostUserTransactionsProvider =
    FutureProvider.family<List<PaymentRecord>, String>(
      (ref, userId) =>
          ref.watch(paymentServiceProvider).transactionsForUser(userId),
    );

class HostSessionManagementController extends Notifier<AsyncValue<void>> {
  HostSessionManagementController(this.sessionId);

  final String sessionId;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> selectPlayers(String courtId, List<String> playerIds) => _mutate(
    () => ref
        .read(sessionServiceProvider)
        .selectPlayers(
          courtId,
          playerIds,
        ),
  );

  Future<bool> startSession() => _mutate(
    () => ref.read(sessionServiceProvider).startSession(sessionId),
  );

  Future<bool> endSession() => _mutate(
    () => ref.read(sessionServiceProvider).endSession(sessionId),
  );

  Future<bool> cancelSession() => _mutate(
    () => ref.read(sessionServiceProvider).cancel(sessionId),
  );

  Future<bool> deselectPlayers(String courtId) => _mutate(
    () => ref.read(sessionServiceProvider).deselectPlayers(courtId),
  );

  Future<bool> startMatch(String courtId) => _mutate(
    () => ref.read(sessionServiceProvider).startMatch(courtId),
  );

  Future<bool> endMatch(String courtId) => _mutate(
    () => ref.read(sessionServiceProvider).endMatch(courtId),
  );

  Future<bool> updateRegistration(
    String playerId, {
    required bool approved,
  }) => _mutate(
    () => ref
        .read(sessionServiceProvider)
        .updateRegistration(sessionId, playerId, approved: approved),
    refreshPayments: approved,
  );

  Future<bool> removePlayer(String playerId) => _mutate(
    () => ref.read(sessionServiceProvider).removePlayer(sessionId, playerId),
    refreshPayments: true,
  );

  Future<bool> toggleCheckIn(String playerId) => _mutate(
    () => ref.read(sessionServiceProvider).toggleInactive(sessionId, playerId),
  );

  Future<bool> approvePayment(String paymentId) => _mutate(
    () => ref.read(paymentServiceProvider).approve(paymentId),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> rejectPayment(String paymentId, String reason) => _mutate(
    () => ref.read(paymentServiceProvider).reject(paymentId, reason),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> bulkApprove(List<String> paymentIds) => _mutate(
    () => ref.read(paymentServiceProvider).bulkApprove(paymentIds),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> saveSettings({
    String? id,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) => _mutate(
    () => ref
        .read(paymentServiceProvider)
        .saveSettings(
          id: id,
          bankName: bankName,
          accountNumber: accountNumber,
          accountHolder: accountHolder,
        ),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> setDefaultSettings(String id) => _mutate(
    () => ref.read(paymentServiceProvider).setDefault(id),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> deleteSettings(String id) => _mutate(
    () => ref.read(paymentServiceProvider).deleteSettings(id),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> setSplitAmount(int totalAmount) => _mutate(
    () => ref
        .read(paymentServiceProvider)
        .setSplitAmount(
          sessionId,
          totalAmount,
        ),
    refreshPayments: true,
  );

  Future<bool> saveExpense({
    String? expenseId,
    required String name,
    required int amount,
  }) => _mutate(
    () => ref
        .read(paymentServiceProvider)
        .saveExpense(
          sessionId,
          expenseId: expenseId,
          name: name,
          amount: amount,
        ),
    refreshSession: false,
    refreshExpenses: true,
  );

  Future<bool> deleteExpense(String expenseId) => _mutate(
    () => ref.read(paymentServiceProvider).deleteExpense(sessionId, expenseId),
    refreshSession: false,
    refreshExpenses: true,
  );

  Future<bool> _mutate(
    Future<void> Function() operation, {
    bool refreshSession = true,
    bool refreshPayments = false,
    bool refreshSettings = false,
    bool refreshExpenses = false,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(operation);
    state = result;
    if (result.hasError) return false;
    if (refreshSession) ref.invalidate(sessionDetailProvider(sessionId));
    if (refreshPayments) ref.invalidate(paymentLedgerProvider(sessionId));
    if (refreshSettings) ref.invalidate(paymentSettingsProvider);
    if (refreshExpenses) ref.invalidate(sessionExpensesProvider(sessionId));
    return true;
  }
}

final hostSessionManagementControllerProvider =
    NotifierProvider.family<
      HostSessionManagementController,
      AsyncValue<void>,
      String
    >(HostSessionManagementController.new);
