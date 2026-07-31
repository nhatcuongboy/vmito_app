import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/domain/repositories/payment_repository.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<PaymentLedger> ledger(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionPayments(sessionId),
    );
    return unwrap(response.data, PaymentLedger.fromJson);
  }

  @override
  Future<List<HostPaymentSettings>> settings() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentSettings,
    );
    return unwrapList(response.data, HostPaymentSettings.fromJson);
  }

  @override
  Future<void> approve(String paymentId) async {
    await _client.post<void>(
      ApiEndpoints.paymentApprove(paymentId),
      data: const <String, dynamic>{},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> reject(String paymentId, String reason) async {
    await _client.post<void>(
      ApiEndpoints.paymentReject(paymentId),
      data: {'hostNotes': reason},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> bulkApprove(List<String> paymentIds) async {
    await _client.post<void>(
      ApiEndpoints.paymentBulkApprove,
      data: {'paymentIds': paymentIds},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
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

  @override
  Future<void> setDefault(String id) async {
    await _client.post<void>(
      ApiEndpoints.paymentSettingDefault(id),
      data: const <String, dynamic>{},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> deleteSettings(String id) async {
    await _client.delete<void>(
      ApiEndpoints.paymentSetting(id),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> setSplitAmount(String sessionId, int totalAmount) async {
    await _client.post<void>(
      ApiEndpoints.sessionPaymentSplit(sessionId),
      data: {'totalAmount': totalAmount},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<SessionExpense>> expenses(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionExpenses(sessionId),
    );
    return unwrapList(response.data, SessionExpense.fromJson);
  }

  @override
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

  @override
  Future<void> deleteExpense(String sessionId, String expenseId) async {
    await _client.delete<void>(
      ApiEndpoints.sessionExpense(sessionId, expenseId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<HostTransactionSummary>> hostSummary() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.hostPaymentSummary,
    );
    return unwrapList(response.data, HostTransactionSummary.fromJson);
  }

  @override
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

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepositoryImpl(ref.watch(apiClientProvider)),
);
