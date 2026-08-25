import 'dart:typed_data';

import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

/// The payment resource's data boundary — the manual bank-transfer ledger.
///
/// There is no payment gateway: a host records what a player transferred and
/// approves or rejects it, so every method here is a ledger operation rather
/// than a charge.
abstract interface class PaymentRepository {
  Future<PaymentLedger> ledger(String sessionId);

  Future<List<HostPaymentSettings>> settings();

  Future<void> approve(
    String paymentId, {
    String? hostNotes,
    int? amount,
    PaymentMethod? paymentMethod,
  });

  Future<void> reject(String paymentId, String reason);

  Future<void> bulkApprove(List<String> paymentIds);

  Future<void> saveSettings({
    String? id,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? qrCodeUrl,
    bool clearQrCode = false,
  });

  Future<String> uploadQrCode(Uint8List bytes, String filename);

  Future<List<VietnamBank>> vietnamBanks();

  Future<void> setDefault(String id);

  Future<void> deleteSettings(String id);

  Future<void> setSplitAmount(String sessionId, int totalAmount);

  Future<SessionFeeConfig?> feeConfig(String sessionId);

  Future<void> saveFeeConfig(String sessionId, SessionFeeConfig config);

  Future<void> deleteFeeConfig(String sessionId);

  Future<FeeRecalculationResult> recalculatePayments(String sessionId);

  Future<List<SessionExpense>> expenses(String sessionId);

  Future<void> saveExpense(
    String sessionId, {
    String? expenseId,
    required String name,
    required int amount,
  });

  Future<void> deleteExpense(String sessionId, String expenseId);

  Future<List<HostTransactionSummary>> hostSummary();

  Future<List<PaymentRecord>> transactionsForUser(String userId);

  Future<HostFinanceReport> financeReport(HostFinanceQuery query);

  Future<void> remindPayment(String paymentId);

  Future<List<PaymentReminder>> remindersForCreator();

  Future<void> remindUser(String userId);
}
