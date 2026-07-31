import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_ledger_view.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_settings_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_expenses_card.dart';

class HostPaymentLedgerTab extends ConsumerWidget {
  const HostPaymentLedgerTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(paymentLedgerProvider(session.id));
    final settings = ref.watch(paymentSettingsProvider);
    final expenses = ref.watch(sessionExpensesProvider(session.id));
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(paymentLedgerProvider(session.id))
          ..invalidate(paymentSettingsProvider)
          ..invalidate(sessionExpensesProvider(session.id));
        await ref.read(paymentLedgerProvider(session.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PaymentSettingsCard(sessionId: session.id, settings: settings),
          const SizedBox(height: AppSpacing.md),
          ledger.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppErrorView(
              error: error,
              onRetry: () => ref.invalidate(
                paymentLedgerProvider(session.id),
              ),
            ),
            data: (value) => PaymentLedgerView(
              session: session,
              ledger: value,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SessionExpensesCard(sessionId: session.id, expenses: expenses),
        ],
      ),
    );
  }
}
