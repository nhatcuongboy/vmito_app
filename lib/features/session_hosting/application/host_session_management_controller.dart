// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

class HostSessionManagementController extends Notifier<AsyncValue<void>> {
  HostSessionManagementController(this.sessionId);

  final String sessionId;

  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> startSession() => _mutate(
    () => ref.read(sessionRepositoryProvider).startSession(sessionId),
  );

  Future<bool> endSession() => _mutate(
    () => ref.read(sessionRepositoryProvider).endSession(sessionId),
  );

  Future<bool> cancelSession() => _mutate(
    () => ref.read(sessionRepositoryProvider).cancel(sessionId),
  );

  Future<bool> updateRegistration(
    String playerId, {
    required bool approved,
  }) => _mutate(
    () => ref
        .read(sessionRepositoryProvider)
        .updateRegistration(sessionId, playerId, approved: approved),
    refreshPayments: approved,
  );

  Future<bool> removePlayer(String playerId) => _mutate(
    () => ref.read(sessionRepositoryProvider).removePlayer(sessionId, playerId),
    refreshPayments: true,
  );

  Future<bool> updatePlayer(
    String playerId,
    Map<String, dynamic> player, {
    required bool shouldRecalculatePayments,
  }) async {
    final updated = await _mutate(
      () => ref
          .read(sessionRepositoryProvider)
          .updatePlayer(sessionId, playerId, player),
      refreshPayments: shouldRecalculatePayments,
    );
    if (updated && shouldRecalculatePayments) {
      // The backend derives player payment rows from gender and club settings.
      // Recalculate after persisting the edited player, as web does.
      await recalculatePayments();
    }
    return updated;
  }

  Future<bool> toggleCheckIn(String playerId) => _mutate(
    () =>
        ref.read(sessionRepositoryProvider).toggleInactive(sessionId, playerId),
  );

  Future<bool> approvePayment(
    String paymentId, {
    String? hostNotes,
    int? amount,
    PaymentMethod? paymentMethod,
  }) => _mutate(
    () => ref
        .read(paymentRepositoryProvider)
        .approve(
          paymentId,
          hostNotes: hostNotes,
          amount: amount,
          paymentMethod: paymentMethod,
        ),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> rejectPayment(String paymentId, String reason) => _mutate(
    () => ref.read(paymentRepositoryProvider).reject(paymentId, reason),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> bulkApprove(List<String> paymentIds) => _mutate(
    () => ref.read(paymentRepositoryProvider).bulkApprove(paymentIds),
    refreshSession: false,
    refreshPayments: true,
  );

  Future<bool> saveSettings({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? qrCodeUrl,
    bool clearQrCode = false,
  }) => _mutate(
    () => ref
        .read(paymentRepositoryProvider)
        .saveSettings(
          id: id,
          bankName: bankName,
          accountNumber: accountNumber,
          accountHolder: accountHolder,
          qrCodeUrl: qrCodeUrl,
          clearQrCode: clearQrCode,
        ),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> setDefaultSettings(String id) => _mutate(
    () => ref.read(paymentRepositoryProvider).setDefault(id),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> deleteSettings(String id) => _mutate(
    () => ref.read(paymentRepositoryProvider).deleteSettings(id),
    refreshSession: false,
    refreshSettings: true,
  );

  Future<bool> setSplitAmount(int totalAmount) => _mutate(
    () => ref
        .read(paymentRepositoryProvider)
        .setSplitAmount(
          sessionId,
          totalAmount,
        ),
    refreshPayments: true,
  );

  Future<String?> uploadQrCode(Uint8List bytes, String filename) async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    try {
      final url = await ref
          .read(paymentRepositoryProvider)
          .uploadQrCode(bytes, filename);
      state = const AsyncValue.data(null);
      return url;
    } on Object catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<bool> saveFeeConfig(SessionFeeConfig config) => _mutate(
    () => ref.read(paymentRepositoryProvider).saveFeeConfig(sessionId, config),
    refreshPayments: true,
    refreshFeeConfig: true,
  );

  Future<bool> deleteFeeConfig() => _mutate(
    () => ref.read(paymentRepositoryProvider).deleteFeeConfig(sessionId),
    refreshPayments: true,
    refreshFeeConfig: true,
  );

  Future<int?> recalculatePayments() async {
    if (state.isLoading) return null;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(paymentRepositoryProvider).recalculatePayments(sessionId),
    );
    if (result.hasError) {
      state = AsyncValue.error(result.error!, result.stackTrace!);
      return null;
    }
    state = const AsyncValue.data(null);
    ref
      ..invalidate(paymentLedgerProvider(sessionId))
      ..invalidate(sessionDetailProvider(sessionId));
    return result.value!.updated;
  }

  Future<bool> remindPayment(String paymentId) => _mutate(
    () => ref.read(paymentRepositoryProvider).remindPayment(paymentId),
    refreshSession: false,
    refreshReminders: true,
  );

  Future<bool> saveExpense({
    String? expenseId,
    required String name,
    required int amount,
  }) => _mutate(
    () => ref
        .read(paymentRepositoryProvider)
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
    () =>
        ref.read(paymentRepositoryProvider).deleteExpense(sessionId, expenseId),
    refreshSession: false,
    refreshExpenses: true,
  );

  Future<bool> _mutate(
    Future<void> Function() operation, {
    bool refreshSession = true,
    bool refreshPayments = false,
    bool refreshSettings = false,
    bool refreshExpenses = false,
    bool refreshFeeConfig = false,
    bool refreshReminders = false,
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
    if (refreshFeeConfig) ref.invalidate(sessionFeeConfigProvider(sessionId));
    if (refreshReminders) ref.invalidate(paymentRemindersProvider);
    return true;
  }
}

final hostSessionManagementControllerProvider =
    NotifierProvider.family<
      HostSessionManagementController,
      AsyncValue<void>,
      String
    >(HostSessionManagementController.new);
