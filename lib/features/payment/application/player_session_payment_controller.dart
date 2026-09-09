// Provider declarations intentionally use inferred family types.
// ignore_for_file: specify_nonobvious_property_types

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';

class PlayerSessionPayments {
  const PlayerSessionPayments({
    required this.records,
    required this.hostSettings,
  });

  final List<PaymentRecord> records;
  final HostPaymentSettings? hostSettings;

  int get totalAmount => records.fold(0, (total, item) => total + item.amount);
  int get paidAmount => records
      .where((item) => item.status == PaymentStatus.approved)
      .fold(0, (total, item) => total + item.amount);
  int get pendingAmount => totalAmount - paidAmount;
}

final playerSessionPaymentsProvider =
    FutureProvider.family<PlayerSessionPayments, String>((
      ref,
      sessionId,
    ) async {
      final session = await ref.watch(sessionDetailProvider(sessionId).future);
      final repository = ref.watch(paymentRepositoryProvider);
      final recordsFuture = repository.mySessionPayments(sessionId);
      final settingsFuture = session.hostId == null
          ? Future<HostPaymentSettings?>.value(null)
          : repository.hostSettings(session.hostId!);
      return PlayerSessionPayments(
        records: await recordsFuture,
        hostSettings: await settingsFuture,
      );
    });

class PlayerPaymentActionState {
  const PlayerPaymentActionState({this.busyPaymentId, this.uploading = false});

  final String? busyPaymentId;
  final bool uploading;
  bool get isBusy => busyPaymentId != null || uploading;
}

class PlayerSessionPaymentController
    extends Notifier<PlayerPaymentActionState> {
  PlayerSessionPaymentController(this.sessionId);

  final String sessionId;

  @override
  PlayerPaymentActionState build() => const PlayerPaymentActionState();

  Future<({String url, String publicId})?> upload(
    Uint8List bytes,
    String filename,
  ) async {
    if (state.isBusy) return null;
    state = const PlayerPaymentActionState(uploading: true);
    try {
      return await ref
          .read(paymentRepositoryProvider)
          .uploadPaymentProof(bytes, filename);
    } finally {
      state = const PlayerPaymentActionState();
    }
  }

  Future<bool> submit(
    String paymentId, {
    required PaymentMethod method,
    String? proofImageUrl,
    String? proofNotes,
  }) async {
    if (state.isBusy) return false;
    state = PlayerPaymentActionState(busyPaymentId: paymentId);
    try {
      await ref
          .read(paymentRepositoryProvider)
          .submitPayment(
            paymentId,
            paymentMethod: method,
            proofImageUrl: proofImageUrl,
            proofNotes: proofNotes,
          );
      ref.invalidate(playerSessionPaymentsProvider(sessionId));
      return true;
    } on Object {
      return false;
    } finally {
      state = const PlayerPaymentActionState();
    }
  }
}

final playerSessionPaymentControllerProvider =
    NotifierProvider.family<
      PlayerSessionPaymentController,
      PlayerPaymentActionState,
      String
    >(PlayerSessionPaymentController.new);
