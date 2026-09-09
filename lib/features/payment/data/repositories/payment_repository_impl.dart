import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/domain/repositories/payment_repository.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  PaymentRepositoryImpl(this._client, {Dio? publicDio})
    : _publicDio = publicDio ?? Dio();

  final ApiClient _client;
  final Dio _publicDio;

  @override
  Future<PaymentLedger> ledger(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionPayments(sessionId),
    );
    return unwrap(response.data, PaymentLedger.fromJson);
  }

  @override
  Future<List<PaymentRecord>> mySessionPayments(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mySessionPayments(sessionId),
    );
    return unwrapList(response.data, PaymentRecord.fromJson);
  }

  @override
  Future<HostPaymentSettings?> hostSettings(String hostId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.hostPaymentSettings(hostId),
      );
      final body = response.data;
      final payload = body?['success'] == null ? body : body?['data'];
      if (payload == null) return null;
      return HostPaymentSettings.fromJson(
        Map<String, dynamic>.from(payload as Map),
      );
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<PaymentRecord> submitPayment(
    String paymentId, {
    required PaymentMethod paymentMethod,
    String? proofImageUrl,
    String? proofNotes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentSubmit(paymentId),
      data: {
        'paymentMethod': paymentMethod == PaymentMethod.bankTransfer
            ? 'BANK_TRANSFER'
            : 'CASH',
        if (proofImageUrl?.trim().isNotEmpty ?? false)
          'proofImageUrl': proofImageUrl!.trim(),
        if (proofNotes?.trim().isNotEmpty ?? false)
          'proofNotes': proofNotes!.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, PaymentRecord.fromJson);
  }

  @override
  Future<List<HostPaymentSettings>> settings() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentSettings,
    );
    return unwrapList(response.data, HostPaymentSettings.fromJson);
  }

  @override
  Future<void> approve(
    String paymentId, {
    String? hostNotes,
    int? amount,
    PaymentMethod? paymentMethod,
  }) async {
    await _client.post<void>(
      ApiEndpoints.paymentApprove(paymentId),
      data: <String, dynamic>{
        if (hostNotes?.trim().isNotEmpty ?? false)
          'hostNotes': hostNotes!.trim(),
        'amount': ?amount,
        if (paymentMethod != null)
          'paymentMethod': paymentMethod == PaymentMethod.bankTransfer
              ? 'BANK_TRANSFER'
              : 'CASH',
      },
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
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? qrCodeUrl,
    bool clearQrCode = false,
  }) async {
    final data = {
      'bankName': bankName?.trim().isEmpty ?? true ? null : bankName!.trim(),
      'bankAccountNumber': accountNumber?.trim().isEmpty ?? true
          ? null
          : accountNumber!.trim(),
      'accountHolderName': accountHolder?.trim().isEmpty ?? true
          ? null
          : accountHolder!.trim(),
      if (qrCodeUrl?.trim().isNotEmpty ?? false) 'qrCodeUrl': qrCodeUrl!.trim(),
      if (clearQrCode) 'qrCodeUrl': null,
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
  Future<String> uploadQrCode(Uint8List bytes, String filename) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1200,
      minHeight: 1200,
      quality: 82,
    );
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentQrUpload,
      data: FormData.fromMap({
        'qrCode': MultipartFile.fromBytes(compressed, filename: filename),
      }),
      options: apiOptions(skipGlobalError: true),
    );
    final result = unwrap(
      response.data,
      (json) => json['url'] as String? ?? '',
    );
    if (result.isEmpty) {
      throw const FormatException('QR upload returned no URL');
    }
    return result;
  }

  @override
  Future<List<VietnamBank>> vietnamBanks() async {
    // A separate client deliberately prevents the app API's auth interceptor
    // from forwarding the user's access token to this public third party.
    final response = await _publicDio.get<Map<String, dynamic>>(
      'https://api.vietqr.io/v2/banks',
    );
    final body = response.data;
    if (body?['code'] != '00' || body?['data'] is! List) return const [];
    return (body!['data'] as List<dynamic>)
        .whereType<Map<Object?, Object?>>()
        .map((item) => VietnamBank.fromJson(item.cast<String, dynamic>()))
        .where((bank) => bank.code.isNotEmpty)
        .toList(growable: false);
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
  Future<SessionFeeConfig?> feeConfig(String sessionId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.sessionFeeConfig(sessionId),
      );
      return unwrap(response.data, SessionFeeConfig.fromJson);
    } on ApiException catch (error) {
      if (error.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<void> saveFeeConfig(
    String sessionId,
    SessionFeeConfig config,
  ) async {
    final data = <String, dynamic>{
      'feeType': config.isSplitEvenly ? 'SPLIT_EVENLY' : 'FIXED',
      if (!config.isSplitEvenly) 'maleFee': config.maleFee,
      if (!config.isSplitEvenly) 'femaleFee': config.femaleFee,
      if (config.notes?.trim().isNotEmpty ?? false)
        'notes': config.notes!.trim(),
    };
    final existing = await feeConfig(sessionId);
    if (existing == null) {
      await _client.post<void>(
        ApiEndpoints.sessionFeeConfig(sessionId),
        data: data,
        options: apiOptions(skipGlobalError: true),
      );
    } else {
      await _client.put<void>(
        ApiEndpoints.sessionFeeConfig(sessionId),
        data: data,
        options: apiOptions(skipGlobalError: true),
      );
    }
  }

  @override
  Future<void> deleteFeeConfig(String sessionId) async {
    await _client.delete<void>(
      ApiEndpoints.sessionFeeConfig(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<FeeRecalculationResult> recalculatePayments(String sessionId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.sessionFeeRecalculate(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, FeeRecalculationResult.fromJson);
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

  @override
  Future<HostFinanceReport> financeReport(HostFinanceQuery query) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.hostFinanceReport,
      queryParameters: query.toQueryParameters(),
    );
    return unwrap(response.data, HostFinanceReport.fromJson);
  }

  @override
  Future<void> remindPayment(String paymentId) async {
    await _client.post<void>(
      ApiEndpoints.paymentReminders,
      data: {'paymentId': paymentId},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<PaymentReminder>> remindersForCreator() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentReminders,
      queryParameters: const {'role': 'creator'},
    );
    return unwrapList(response.data, PaymentReminder.fromJson);
  }

  @override
  Future<void> remindUser(String userId) async {
    await _client.post<void>(
      ApiEndpoints.aggregatePaymentReminder,
      data: {'recipientUserId': userId},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<PaymentReminder>> getReminders({
    required String role,
    PaymentReminderStatus? status,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.paymentReminders,
      queryParameters: {
        'role': role,
        if (status != null) 'status': status.toJson(),
      },
    );
    return unwrapList(response.data, PaymentReminder.fromJson);
  }

  @override
  Future<PaymentReminder> createSingleReminder({
    required String paymentId,
    String? note,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminders,
      data: {
        'paymentId': paymentId,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> createAggregateReminder({
    required String recipientUserId,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.aggregatePaymentReminder,
      data: {'recipientUserId': recipientUserId},
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> createCustomReminder({
    required String recipientUserId,
    required int amount,
    required String note,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminderCustom,
      data: {
        'recipientUserId': recipientUserId,
        'amount': amount,
        'note': note.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> remindAgain(String reminderId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminderRemind(reminderId),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> markReminderCollected(String reminderId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminderMarkCollected(reminderId),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> markReminderPaid(
    String reminderId, {
    required PaymentMethod paymentMethod,
    String? proofImageUrl,
    String? proofImagePublicId,
    String? proofNotes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminderMarkPaid(reminderId),
      data: {
        'paymentMethod': paymentMethod == PaymentMethod.bankTransfer
            ? 'BANK_TRANSFER'
            : 'CASH',
        if (proofImageUrl != null) 'proofImageUrl': proofImageUrl,
        if (proofImagePublicId != null)
          'proofImagePublicId': proofImagePublicId,
        if (proofNotes != null && proofNotes.trim().isNotEmpty)
          'proofNotes': proofNotes.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<PaymentReminder> rejectReminder(
    String reminderId, {
    String? hostNotes,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.paymentReminderReject(reminderId),
      data: {
        if (hostNotes != null && hostNotes.trim().isNotEmpty)
          'hostNotes': hostNotes.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => PaymentReminder.fromJson(Map<String, dynamic>.from(json)),
    );
  }

  @override
  Future<({String url, String publicId})> uploadPaymentProof(
    Uint8List bytes,
    String filename,
  ) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1200,
      minHeight: 1200,
      quality: 82,
    );
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.uploadPaymentProof,
      data: FormData.fromMap({
        'proof': MultipartFile.fromBytes(compressed, filename: filename),
      }),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(
      response.data,
      (json) => (
        url: json['url'] as String? ?? '',
        publicId: json['publicId'] as String? ?? '',
      ),
    );
  }

  @override
  Future<List<PaymentReminderUser>> searchUsers(String query) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.users,
      queryParameters: {
        if (query.trim().isNotEmpty) 'search': query.trim(),
      },
    );
    return unwrapList(response.data, PaymentReminderUser.fromJson);
  }
}

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepositoryImpl(ref.watch(apiClientProvider)),
);
