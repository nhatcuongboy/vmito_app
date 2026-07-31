import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/session/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class TransactionDashboardScreen extends ConsumerWidget {
  const TransactionDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaries = ref.watch(hostTransactionSummaryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.transactionDashboardTitle)),
      body: summaries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(hostTransactionSummaryProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(hostTransactionSummaryProvider.future),
          child: items.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 160),
                    Center(child: Text(l10n.transactionDashboardEmpty)),
                  ],
                )
              : _SummaryList(items: items),
        ),
      ),
    );
  }
}

class _SummaryList extends StatelessWidget {
  const _SummaryList({required this.items});

  final List<HostTransactionSummary> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final total = items.fold<int>(0, (sum, item) => sum + item.totalAmount);
    final paid = items.fold<int>(0, (sum, item) => sum + item.paidAmount);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            Chip(
              label: Text(
                '${l10n.hostManagePaymentTotal}: '
                '${Money.vnd(total, locale: locale)}',
              ),
            ),
            Chip(
              label: Text(
                '${l10n.hostManagePaymentPaid}: '
                '${Money.vnd(paid, locale: locale)}',
              ),
            ),
            Chip(
              label: Text(
                '${l10n.hostManagePaymentOutstanding}: '
                '${Money.vnd(total - paid, locale: locale)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        for (final item in items)
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(
                  item.userName.trim().isEmpty
                      ? '•'
                      : item.userName.trim()[0].toUpperCase(),
                ),
              ),
              title: Text(item.userName),
              subtitle: Text(
                '${item.totalSessions} ${l10n.transactionSessions} · '
                '${l10n.hostManagePaymentOutstanding}: '
                '${Money.vnd(item.pendingAmount, locale: locale)}',
              ),
              trailing: item.userId == 'guest'
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: item.userId == 'guest'
                  ? null
                  : () => showModalBottomSheet<void>(
                      context: context,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (_) => _TransactionDetail(
                        userId: item.userId,
                        userName: item.userName,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _TransactionDetail extends ConsumerWidget {
  const _TransactionDetail({required this.userId, required this.userName});

  final String userId;
  final String userName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final payments = ref.watch(hostUserTransactionsProvider(userId));
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(userName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: payments.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => AppErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(
                      hostUserTransactionsProvider(userId),
                    ),
                  ),
                  data: (items) => ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final payment = items[index];
                      return ListTile(
                        title: Text(
                          payment.sessionName ?? l10n.hostManagePayments,
                        ),
                        subtitle: Text(
                          _statusLabel(l10n, payment.status),
                        ),
                        trailing: Text(
                          Money.vnd(payment.amount, locale: locale),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, PaymentStatus status) =>
      switch (status) {
        PaymentStatus.pending => l10n.hostManagePaymentPending,
        PaymentStatus.submitted => l10n.hostManagePaymentSubmitted,
        PaymentStatus.approved => l10n.hostManagePaymentApproved,
        PaymentStatus.rejected => l10n.hostManagePaymentRejected,
      };
}
