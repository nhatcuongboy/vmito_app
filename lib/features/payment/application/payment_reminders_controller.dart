import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/future_provider.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/domain/repositories/payment_repository.dart';

final FutureProviderFamily<List<PaymentReminder>, String>
remindersListProvider = FutureProvider.family<List<PaymentReminder>, String>((
  ref,
  role,
) async {
  final repository = ref.watch(paymentRepositoryProvider);
  return repository.getReminders(role: role);
});

final FutureProviderFamily<List<PaymentReminderUser>, String>
reminderUserSearchProvider =
    FutureProvider.family<List<PaymentReminderUser>, String>((
      ref,
      query,
    ) async {
      if (query.trim().isEmpty) return const [];
      final repository = ref.watch(paymentRepositoryProvider);
      return repository.searchUsers(query.trim());
    });

class PaymentRemindersController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  PaymentRepository get _repository => ref.read(paymentRepositoryProvider);

  void _invalidateAll() {
    ref.invalidate(remindersListProvider('creator'));
    ref.invalidate(remindersListProvider('recipient'));
    ref.invalidate(paymentRemindersProvider);
  }

  Future<bool> remindAgain(String reminderId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.remindAgain(reminderId),
    );
    if (!state.hasError) {
      _invalidateAll();
      return true;
    }
    return false;
  }

  Future<bool> markCollected(String reminderId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.markReminderCollected(reminderId),
    );
    if (!state.hasError) {
      _invalidateAll();
      return true;
    }
    return false;
  }

  Future<bool> markPaid(
    String reminderId, {
    required PaymentMethod paymentMethod,
    String? proofImageUrl,
    String? proofImagePublicId,
    String? proofNotes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.markReminderPaid(
        reminderId,
        paymentMethod: paymentMethod,
        proofImageUrl: proofImageUrl,
        proofImagePublicId: proofImagePublicId,
        proofNotes: proofNotes,
      ),
    );
    if (!state.hasError) {
      _invalidateAll();
      return true;
    }
    return false;
  }

  Future<bool> reject(
    String reminderId, {
    String? hostNotes,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.rejectReminder(
        reminderId,
        hostNotes: hostNotes,
      ),
    );
    if (!state.hasError) {
      _invalidateAll();
      return true;
    }
    return false;
  }

  Future<bool> createCustomReminder({
    required String recipientUserId,
    required int amount,
    required String note,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repository.createCustomReminder(
        recipientUserId: recipientUserId,
        amount: amount,
        note: note,
      ),
    );
    if (!state.hasError) {
      _invalidateAll();
      return true;
    }
    return false;
  }

  Future<({String url, String publicId})?> uploadProof(
    Uint8List bytes,
    String filename,
  ) async {
    try {
      return await _repository.uploadPaymentProof(bytes, filename);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

final paymentRemindersControllerProvider =
    NotifierProvider<PaymentRemindersController, AsyncValue<void>>(
      PaymentRemindersController.new,
    );
