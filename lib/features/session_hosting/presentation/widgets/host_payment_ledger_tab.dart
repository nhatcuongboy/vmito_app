import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_ledger_view.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_settings_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_expenses_card.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/session_fee_config_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class HostPaymentLedgerTab extends ConsumerWidget {
  const HostPaymentLedgerTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(paymentLedgerProvider(session.id));
    final settings = ref.watch(paymentSettingsProvider);
    final expenses = ref.watch(sessionExpensesProvider(session.id));
    final reminders = ref.watch(paymentRemindersProvider);
    final expenseTotal =
        expenses.value?.fold<int>(
          0,
          (sum, item) => sum + item.amount,
        ) ??
        0;
    return RefreshIndicator(
      onRefresh: () => _refresh(ref),
      child: LayoutBuilder(
        builder: (context, constraints) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AdaptiveTopCards(
                      sessionId: session.id,
                      settings: settings,
                      wide: constraints.maxWidth >= 720,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ledger.when(
                      loading: () => const PaymentLedgerSkeleton(),
                      error: (error, _) => Card(
                        child: AppErrorView(
                          error: error,
                          onRetry: () => ref.invalidate(
                            paymentLedgerProvider(session.id),
                          ),
                        ),
                      ),
                      data: (value) => PaymentLedgerView(
                        session: session,
                        ledger: value,
                        totalExpenses: expenseTotal,
                        reminders: reminders.value ?? const {},
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SessionExpensesCard(
                      sessionId: session.id,
                      expenses: expenses,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: OutlinedButton.icon(
                        key: const Key('payment-view-all-transactions'),
                        onPressed: () => context.push(AppRoutes.transactions),
                        icon: const Icon(AppIcons.externalLink),
                        label: Text(
                          AppLocalizations.of(
                            context,
                          ).hostManageViewAllTransactions,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(paymentLedgerProvider(session.id))
      ..invalidate(paymentSettingsProvider)
      ..invalidate(sessionExpensesProvider(session.id))
      ..invalidate(sessionFeeConfigProvider(session.id))
      ..invalidate(paymentRemindersProvider);
    await Future.wait([
      ref.read(paymentLedgerProvider(session.id).future),
      ref.read(paymentSettingsProvider.future),
      ref.read(sessionExpensesProvider(session.id).future),
    ]);
  }
}

class _AdaptiveTopCards extends StatelessWidget {
  const _AdaptiveTopCards({
    required this.sessionId,
    required this.settings,
    required this.wide,
  });
  final String sessionId;
  final AsyncValue<List<HostPaymentSettings>> settings;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final fee = SessionFeeConfigCard(sessionId: sessionId);
    final payment = PaymentSettingsCard(
      sessionId: sessionId,
      settings: settings,
    );
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fee,
          const SizedBox(height: AppSpacing.md),
          payment,
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: fee),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: payment),
        ],
      ),
    );
  }
}
