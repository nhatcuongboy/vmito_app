import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/session/domain/payment.dart';

class PaymentService {
  const PaymentService(this._client);

  final ApiClient _client;

  Future<PaymentLedger> ledger(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionPayments(sessionId),
    );
    return unwrap(response.data, PaymentLedger.fromJson);
  }

  Future<List<HostPaymentSettings>> settings() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentSettings,
    );
    return unwrapList(response.data, HostPaymentSettings.fromJson);
  }

  Future<void> approve(String paymentId) async {
    await _client.post<void>(
      ApiEndpoints.paymentApprove(paymentId),
      data: const <String, dynamic>{},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> reject(String paymentId, String reason) async {
    await _client.post<void>(
      ApiEndpoints.paymentReject(paymentId),
      data: {'hostNotes': reason},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> bulkApprove(List<String> paymentIds) async {
    await _client.post<void>(
      ApiEndpoints.paymentBulkApprove,
      data: {'paymentIds': paymentIds},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> saveSettings({
    String? id,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) async {
    final data = {
      'bankName': bankName,
      'bankAccountNumber': accountNumber,
      'accountHolderName': accountHolder,
      'isDefault': true,
    };
    final options = apiOptions(skipGlobalError: true);
    if (id == null) {
      await _client.post<void>(
        ApiEndpoints.paymentSettings,
        data: data,
        options: options,
      );
    } else {
      await _client.put<void>(
        ApiEndpoints.paymentSetting(id),
        data: data,
        options: options,
      );
    }
  }

  Future<void> setDefault(String id) async {
    await _client.post<void>(
      ApiEndpoints.paymentSettingDefault(id),
      data: const <String, dynamic>{},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> deleteSettings(String id) async {
    await _client.delete<void>(
      ApiEndpoints.paymentSetting(id),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> setSplitAmount(String sessionId, int totalAmount) async {
    await _client.post<void>(
      ApiEndpoints.sessionPaymentSplit(sessionId),
      data: {'totalAmount': totalAmount},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<List<SessionExpense>> expenses(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionExpenses(sessionId),
    );
    return unwrapList(response.data, SessionExpense.fromJson);
  }

  Future<void> saveExpense(
    String sessionId, {
    String? expenseId,
    required String name,
    required int amount,
  }) async {
    final data = {'name': name, 'amount': amount};
    final options = apiOptions(skipGlobalError: true);
    if (expenseId == null) {
      await _client.post<void>(
        ApiEndpoints.sessionExpenses(sessionId),
        data: data,
        options: options,
      );
    } else {
      await _client.patch<void>(
        ApiEndpoints.sessionExpense(sessionId, expenseId),
        data: data,
        options: options,
      );
    }
  }

  Future<void> deleteExpense(String sessionId, String expenseId) async {
    await _client.delete<void>(
      ApiEndpoints.sessionExpense(sessionId, expenseId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<List<HostTransactionSummary>> hostSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.hostPaymentSummary,
    );
    return unwrapList(response.data, HostTransactionSummary.fromJson);
  }

  Future<List<PaymentRecord>> transactionsForUser(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.hostPaymentsForUser(userId),
    );
    final payload = response.data?['success'] == true
        ? response.data!['data']
        : response.data;
    if (payload is! Map || payload['payments'] is! List) return const [];
    return (payload['payments'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(PaymentRecord.fromJson)
        .toList(growable: false);
  }
}

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(ref.watch(apiClientProvider)),
);
