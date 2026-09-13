import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/application/transaction_dashboard_controller.dart';
import 'package:vmito_app/features/payment/domain/form/transaction_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';
import 'package:vmito_app/shared/widgets/app_sheet_grabber.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class PlayerPaymentDetailSheet extends ConsumerWidget {
  const PlayerPaymentDetailSheet({
    required this.summary,
    required this.query,
    super.key,
  });

  final HostTransactionSummary summary;
  final HostFinanceQuery query;

  bool get _canLoad => summary.userId.trim().toLowerCase() != 'guest';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final payments = _canLoad
        ? ref.watch(hostUserTransactionsProvider(summary.userId))
        : const AsyncValue<List<PaymentRecord>>.data([]);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: Column(
          children: [
            const AppSheetGrabber(),
            AppSheetHeader(
              title: summary.userName,
              subtitle:
                  '${l10n.transactionTotal}: '
                  '${Money.vnd(summary.totalAmount, locale: locale)}',
            ),
            Expanded(
              child: payments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => AppErrorView(
                  error: error,
                  onRetry: () => ref.invalidate(
                    hostUserTransactionsProvider(summary.userId),
                  ),
                ),
                data: (rawItems) {
                  final items =
                      rawItems.where((item) => item.isBillable).toList()..sort(
                        (a, b) => _paymentDate(b).compareTo(_paymentDate(a)),
                      );
                  final submitted = items
                      .where((item) => item.status == PaymentStatus.submitted)
                      .toList();
                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.xl,
                    ),
                    children: [
                      _SummaryGrid(summary: summary, locale: locale),
                      if (submitted.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.tonalIcon(
                          onPressed:
                              ref
                                  .watch(transactionDashboardControllerProvider)
                                  .isLoading
                              ? null
                              : () => _bulkApprove(context, ref, submitted),
                          icon: const Icon(AppIcons.checkAll),
                          label: Text(
                            l10n.transactionApproveSubmitted(
                              submitted.length,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      if (items.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            children: [
                              const Icon(AppIcons.receipt, size: 36),
                              const SizedBox(height: AppSpacing.sm),
                              Text(l10n.transactionNoPayments),
                            ],
                          ),
                        )
                      else
                        for (var index = 0; index < items.length; index++) ...[
                          if (index == 0 ||
                              !_sameMonth(
                                _paymentDate(items[index - 1]),
                                _paymentDate(items[index]),
                              ))
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.md,
                                bottom: AppSpacing.sm,
                              ),
                              child: Text(
                                DateFormat.yMMMM(locale).format(
                                  _paymentDate(items[index]).toLocal(),
                                ),
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                          _PaymentCard(
                            payment: items[index],
                            locale: locale,
                            onOpen: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => PaymentReviewSheet(
                                payment: items[index],
                                summary: summary,
                                query: query,
                              ),
                            ),
                            onRemind:
                                items[index].status == PaymentStatus.pending
                                ? () => _remind(context, ref, items[index].id)
                                : null,
                          ),
                        ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bulkApprove(
    BuildContext context,
    WidgetRef ref,
    List<PaymentRecord> payments,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(transactionDashboardControllerProvider.notifier)
        .bulkApprove(
          payments.map((item) => item.id).toList(),
          query: query,
          userId: summary.userId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.transactionActionSuccess : l10n.hostManageActionFailed,
        ),
      ),
    );
  }

  Future<void> _remind(
    BuildContext context,
    WidgetRef ref,
    String paymentId,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref
        .read(transactionDashboardControllerProvider.notifier)
        .remindPayment(paymentId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.transactionReminderSent : l10n.transactionReminderFailed,
        ),
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary, required this.locale});

  final HostTransactionSummary summary;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _SummaryCell(
            label: l10n.transactionTotal,
            value: Money.compactVnd(summary.totalAmount, locale: locale),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryCell(
            label: l10n.transactionCollected,
            value: Money.compactVnd(summary.paidAmount, locale: locale),
            color: AppColors.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryCell(
            label: l10n.transactionOutstanding,
            value: Money.compactVnd(summary.pendingAmount, locale: locale),
            color: AppColors.warning,
          ),
        ),
      ],
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: (color ?? Theme.of(context).colorScheme.primary).withValues(
        alpha: 0.08,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.payment,
    required this.locale,
    required this.onOpen,
    this.onRemind,
  });

  final PaymentRecord payment;
  final String locale;
  final VoidCallback onOpen;
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final accent = switch (payment.status) {
      PaymentStatus.pending => AppColors.warning,
      PaymentStatus.submitted => AppColors.info,
      PaymentStatus.approved => AppColors.success,
      PaymentStatus.rejected => Theme.of(context).colorScheme.error,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              payment.sessionName ?? l10n.hostManagePayments,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              payment.session?.startTime == null
                                  ? l10n.transactionSessions
                                  : Dates.dateOnly(
                                      payment.session!.startTime!,
                                      locale: locale,
                                    ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palette.mutedForeground),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _StatusChip(status: payment.status),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            Money.vnd(payment.amount, locale: locale),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (onRemind != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: onRemind,
                              icon: const Icon(
                                AppIcons.notifications,
                                size: 16,
                              ),
                              label: Text(l10n.transactionRemind),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (label, color) = switch (status) {
      PaymentStatus.pending => (
        l10n.hostManagePaymentPending,
        AppColors.warning,
      ),
      PaymentStatus.submitted => (
        l10n.hostManagePaymentSubmitted,
        AppColors.info,
      ),
      PaymentStatus.approved => (
        l10n.hostManagePaymentApproved,
        AppColors.success,
      ),
      PaymentStatus.rejected => (
        l10n.hostManagePaymentRejected,
        Theme.of(context).colorScheme.error,
      ),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.1),
    );
  }
}

class PaymentReviewSheet extends ConsumerStatefulWidget {
  const PaymentReviewSheet({
    required this.payment,
    required this.summary,
    required this.query,
    super.key,
  });

  final PaymentRecord payment;
  final HostTransactionSummary summary;
  final HostFinanceQuery query;

  @override
  ConsumerState<PaymentReviewSheet> createState() => _PaymentReviewSheetState();
}

class _PaymentReviewSheetState extends ConsumerState<PaymentReviewSheet> {
  late final FormGroup _form = createPaymentReviewForm(widget.payment);

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(transactionDashboardControllerProvider).isLoading;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: AppReactiveForm<void>(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.transactionReviewPayment,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(widget.payment.sessionName ?? l10n.hostManagePayments),
                const SizedBox(height: AppSpacing.md),
                _StatusChip(status: widget.payment.status),
                const SizedBox(height: AppSpacing.md),
                ReactiveTextField<int>(
                  formControlName: PaymentReviewControl.amount,
                  valueAccessor: CurrencyValueAccessor(),
                  inputFormatters: [ThousandsSeparatorFormatter()],
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: l10n.transactionAmount,
                    suffixText: '₫',
                  ),
                  validationMessages: {
                    ValidationMessage.required: (_) =>
                        l10n.transactionAmountInvalid,
                    ValidationMessage.min: (_) => l10n.transactionAmountInvalid,
                    ValidationMessage.number: (_) =>
                        l10n.transactionAmountInvalid,
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveDropdownField<PaymentMethod>(
                  formControlName: PaymentReviewControl.method,
                  decoration: InputDecoration(
                    labelText: l10n.transactionReceiveMethod,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: PaymentMethod.bankTransfer,
                      child: Text(
                        l10n.transactionBankTransfer,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                    DropdownMenuItem(
                      value: PaymentMethod.cash,
                      child: Text(
                        l10n.transactionCash,
                        style: const TextStyle(fontWeight: FontWeight.normal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ReactiveTextField<String>(
                  formControlName: PaymentReviewControl.notes,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.transactionHostNotes,
                    hintText: l10n.transactionHostNotesHint,
                  ),
                ),
                if (widget.payment.proofNotes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.transactionPlayerNotes,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(widget.payment.proofNotes!),
                ],
                if (widget.payment.proofImageUrl?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.transactionProof,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => unawaited(
                      showAppLightbox(
                        context,
                        images: [widget.payment.proofImageUrl!],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: CachedNetworkImage(
                        imageUrl: widget.payment.proofImageUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _reject(context),
                        icon: const Icon(AppIcons.close),
                        label: Text(l10n.hostManageReject),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: busy ? null : () => _approve(context),
                        icon: const Icon(AppIcons.check),
                        label: Text(l10n.hostManageApprove),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve(BuildContext context) async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending) return;
    final ok = await ref
        .read(transactionDashboardControllerProvider.notifier)
        .approve(
          widget.payment.id,
          query: widget.query,
          userId: widget.summary.userId,
          amount: _form.control(PaymentReviewControl.amount).value as int?,
          paymentMethod:
              _form.control(PaymentReviewControl.method).value
                  as PaymentMethod?,
          hostNotes:
              (_form.control(PaymentReviewControl.notes).value as String?)
                  ?.trim(),
        );
    if (!context.mounted) return;
    _finish(context, ok);
  }

  Future<void> _reject(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final notes = (_form.control(PaymentReviewControl.notes).value as String?)
        ?.trim();
    final ok = await ref
        .read(transactionDashboardControllerProvider.notifier)
        .reject(
          widget.payment.id,
          notes?.isNotEmpty ?? false ? notes! : l10n.transactionRejectFallback,
          query: widget.query,
          userId: widget.summary.userId,
        );
    if (!context.mounted) return;
    _finish(context, ok);
  }

  void _finish(BuildContext context, bool ok) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.transactionActionSuccess : l10n.hostManageActionFailed,
        ),
      ),
    );
    if (ok) Navigator.pop(context);
  }
}

DateTime _paymentDate(PaymentRecord payment) =>
    payment.session?.startTime ?? payment.createdAt;

bool _sameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;
