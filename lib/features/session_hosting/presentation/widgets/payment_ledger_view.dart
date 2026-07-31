import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/summary_chip.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class PaymentLedgerView extends ConsumerWidget {
  const PaymentLedgerView({
    required this.session,
    required this.ledger,
    super.key,
  });

  final Session session;
  final PaymentLedger ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final submitted = ledger.payments
        .where((payment) => payment.status == PaymentStatus.submitted)
        .map((payment) => payment.id)
        .toList();
    final controller = ref.read(
      hostSessionManagementControllerProvider(sessionId).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.feeConfig?.isSplitEvenly ?? false) ...[
          FilledButton.tonalIcon(
            onPressed: () => _setSplitAmount(context, controller),
            icon: const Icon(Icons.calculate_outlined),
            label: Text(l10n.setSplitAmount),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            SummaryChip(
              label: l10n.hostManagePaymentTotal,
              value: Money.vnd(ledger.stats.totalAmount, locale: locale),
            ),
            SummaryChip(
              label: l10n.hostManagePaymentPaid,
              value: Money.vnd(ledger.stats.paidAmount, locale: locale),
            ),
            SummaryChip(
              label: l10n.hostManagePaymentOutstanding,
              value: Money.vnd(
                ledger.stats.totalAmount - ledger.stats.paidAmount,
                locale: locale,
              ),
            ),
          ],
        ),
        if (submitted.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.tonalIcon(
            onPressed: () => controller.bulkApprove(submitted),
            icon: const Icon(Icons.done_all_rounded),
            label: Text(l10n.hostManageBulkApprove),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (ledger.payments.isEmpty)
          Text(l10n.hostManageNoPayments)
        else
          for (final payment in ledger.payments)
            Card(
              child: ListTile(
                title: Text(
                  payment.player == null
                      ? l10n.playerNumbered(0)
                      : l10n.playerName(payment.player!),
                ),
                subtitle: Text(_paymentStatus(l10n, payment.status)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(Money.vnd(payment.amount, locale: locale)),
                    if (payment.status != PaymentStatus.approved) ...[
                      IconButton(
                        tooltip: l10n.hostManageReject,
                        onPressed: () async {
                          final reason = await _rejectReason(context);
                          if (reason != null) {
                            await controller.rejectPayment(
                              payment.id,
                              reason,
                            );
                          }
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton(
                        tooltip: l10n.hostManageApprove,
                        onPressed: () => controller.approvePayment(payment.id),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ],
                ),
              ),
            ),
      ],
    );
  }

  String get sessionId => session.id;

  Future<void> _setSplitAmount(
    BuildContext context,
    HostSessionManagementController controller,
  ) async {
    final text = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final amount = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.setSplitAmount),
        content: TextField(
          controller: text,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.hostManagePaymentTotal,
            suffixText: '₫',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(text.text.trim());
              if (value != null && value >= 0) Navigator.pop(context, value);
            },
            child: Text(l10n.hostManageSave),
          ),
        ],
      ),
    );
    text.dispose();
    if (amount != null) await controller.setSplitAmount(amount);
  }

  String _paymentStatus(AppLocalizations l10n, PaymentStatus status) =>
      switch (status) {
        PaymentStatus.pending => l10n.hostManagePaymentPending,
        PaymentStatus.submitted => l10n.hostManagePaymentSubmitted,
        PaymentStatus.approved => l10n.hostManagePaymentApproved,
        PaymentStatus.rejected => l10n.hostManagePaymentRejected,
      };

  Future<String?> _rejectReason(BuildContext context) async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.hostManageConfirmReject),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.hostManageRejectReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () {
              final reason = controller.text.trim();
              if (reason.isNotEmpty) Navigator.pop(context, reason);
            },
            child: Text(l10n.hostManageReject),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }
}
