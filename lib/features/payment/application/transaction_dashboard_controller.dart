// Provider declarations intentionally use inferred types.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';

class TransactionDashboardController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<bool> approve(
    String paymentId, {
    required HostFinanceQuery query,
    required String userId,
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
    query: query,
    userId: userId,
  );

  Future<bool> reject(
    String paymentId,
    String reason, {
    required HostFinanceQuery query,
    required String userId,
  }) => _mutate(
    () => ref.read(paymentRepositoryProvider).reject(paymentId, reason),
    query: query,
    userId: userId,
  );

  Future<bool> bulkApprove(
    List<String> paymentIds, {
    required HostFinanceQuery query,
    required String userId,
  }) => _mutate(
    () => ref.read(paymentRepositoryProvider).bulkApprove(paymentIds),
    query: query,
    userId: userId,
  );

  Future<bool> remindPayment(String paymentId) => _mutate(
    () => ref.read(paymentRepositoryProvider).remindPayment(paymentId),
  );

  Future<bool> remindUser(String userId) => _mutate(
    () => ref.read(paymentRepositoryProvider).remindUser(userId),
  );

  Future<bool> _mutate(
    Future<void> Function() operation, {
    HostFinanceQuery? query,
    String? userId,
  }) async {
    if (state.isLoading) return false;
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(operation);
    state = result;
    if (result.hasError) return false;
    if (query != null) ref.invalidate(hostFinanceReportProvider(query));
    if (userId != null) ref.invalidate(hostUserTransactionsProvider(userId));
    return true;
  }
}

final transactionDashboardControllerProvider =
    NotifierProvider<TransactionDashboardController, AsyncValue<void>>(
      TransactionDashboardController.new,
    );
