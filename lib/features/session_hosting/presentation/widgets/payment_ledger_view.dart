import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/payment/domain/form/host_payment_forms.dart';
import 'package:vmito_app/features/payment/domain/form/transaction_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_section_header_style.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_lightbox.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';

class PaymentLedgerView extends ConsumerStatefulWidget {
  const PaymentLedgerView({
    required this.session,
    required this.ledger,
    required this.totalExpenses,
    required this.reminders,
    super.key,
  });

  final Session session;
  final PaymentLedger ledger;
  final int totalExpenses;
  final Map<String, PaymentReminder> reminders;

  @override
  ConsumerState<PaymentLedgerView> createState() => _PaymentLedgerViewState();
}

class _PaymentLedgerViewState extends ConsumerState<PaymentLedgerView> {
  PaymentStatus? _status;
  String _member = 'all';
  final Set<String> _expandedGroups = {};

  List<PaymentRecord> get _filtered => widget.ledger.payments
      .where((payment) {
        if (_status != null && payment.status != _status) return false;
        final fixed = payment.player?.clubFeeApplied ?? false;
        if (_member == 'fixed' && !fixed) return false;
        if (_member == 'regular' && fixed) return false;
        if (!_member.startsWith('club:')) return true;
        return payment.player?.clubId == _member.substring(5);
      })
      .toList(growable: false);

  List<MapEntry<String, List<PaymentRecord>>> get _groups {
    final grouped = <String, List<PaymentRecord>>{};
    for (final payment in _filtered) {
      final key = payment.registeredByUserId ?? payment.playerId;
      grouped.putIfAbsent(key, () => []).add(payment);
    }
    return grouped.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final submitted = widget.ledger.payments
        .where((payment) => payment.status == PaymentStatus.submitted)
        .map((payment) => payment.id)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.session.feeConfig?.isSplitEvenly ?? false) ...[
          _SplitAmountCard(sessionId: widget.session.id),
          const SizedBox(height: AppSpacing.md),
        ],
        _PaymentSummary(
          ledger: widget.ledger,
          totalExpenses: widget.totalExpenses,
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    Text(
                      l10n.hostManageIncome,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('payment-filter-button'),
                          onPressed: _showFilters,
                          style: PaymentSectionHeaderStyle.actionButtonStyle,
                          icon: const Icon(
                            AppIcons.filter,
                            size: PaymentSectionHeaderStyle.actionIconSize,
                          ),
                          label: Text(l10n.transactionStatusFilter),
                        ),
                        if (submitted.isNotEmpty) ...[
                          FilledButton.tonalIcon(
                            key: const Key('payment-bulk-approve'),
                            onPressed: () => ref
                                .read(
                                  hostSessionManagementControllerProvider(
                                    widget.session.id,
                                  ).notifier,
                                )
                                .bulkApprove(submitted),
                            style: PaymentSectionHeaderStyle.actionButtonStyle,
                            icon: const Icon(
                              AppIcons.checkAll,
                              size: PaymentSectionHeaderStyle.actionIconSize,
                            ),
                            label: Text(
                              '${l10n.hostManageApprove} (${submitted.length})',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                if (_status != null || _member != 'all') ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      if (_status != null)
                        InputChip(
                          label: Text(_statusLabel(l10n, _status!)),
                          onDeleted: () => setState(() => _status = null),
                        ),
                      if (_member != 'all')
                        InputChip(
                          label: Text(_memberLabel(l10n, _member)),
                          onDeleted: () => setState(() => _member = 'all'),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                if (_groups.isEmpty)
                  _PaymentEmpty(label: l10n.hostManageNoPayments)
                else
                  for (final entry in _groups) ...[
                    if (entry.value.length == 1)
                      _PaymentCard(
                        payment: entry.value.single,
                        onTap: () => _openReview(entry.value.single),
                      )
                    else
                      _PaymentGroupCard(
                        groupKey: entry.key,
                        payments: entry.value,
                        expanded: _expandedGroups.contains(entry.key),
                        onToggle: () => setState(() {
                          if (!_expandedGroups.add(entry.key)) {
                            _expandedGroups.remove(entry.key);
                          }
                        }),
                        onOpen: _openReview,
                        onBulkApprove: (ids) => ref
                            .read(
                              hostSessionManagementControllerProvider(
                                widget.session.id,
                              ).notifier,
                            )
                            .bulkApprove(ids),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _memberLabel(AppLocalizations l10n, String member) {
    if (member == 'fixed') return l10n.hostManageFixedMembers;
    if (member == 'regular') return l10n.hostManageRegularMembers;
    if (member.startsWith('club:')) {
      final id = member.substring(5);
      for (final payment in widget.ledger.payments) {
        if (payment.player?.clubId == id) {
          return payment.player?.clubName ?? l10n.hostManageFixedMembers;
        }
      }
    }
    return l10n.transactionFilterAll;
  }

  Future<void> _showFilters() async {
    final value = await showModalBottomSheet<_PaymentFilters>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => _PaymentFilterSheet(
        payments: widget.ledger.payments,
        status: _status,
        member: _member,
      ),
    );
    if (value != null) {
      setState(() {
        _status = value.status;
        _member = value.member;
      });
    }
  }

  Future<void> _openReview(PaymentRecord payment) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => SessionPaymentReviewSheet(
      sessionId: widget.session.id,
      payment: payment,
      reminder: widget.reminders[payment.id],
    ),
  );
}

class _SplitAmountCard extends StatefulWidget {
  const _SplitAmountCard({required this.sessionId});
  final String sessionId;

  @override
  State<_SplitAmountCard> createState() => _SplitAmountCardState();
}

class _SplitAmountCardState extends State<_SplitAmountCard> {
  final FormGroup _form = createSplitAmountForm();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const purple = Colors.deepPurple;
    return Consumer(
      builder: (context, ref, _) => Card(
        color: purple.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: purple.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppReactiveForm(
            formGroup: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.setSplitAmount,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.hostManageSplitAmountDescription),
                const SizedBox(height: AppSpacing.sm),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final field = ReactiveTextField<int>(
                      formControlName: SplitAmountControl.total,
                      valueAccessor: CurrencyValueAccessor(),
                      inputFormatters: [ThousandsSeparatorFormatter()],
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.hostManagePaymentTotal,
                        suffixText: '₫',
                      ),
                      validationMessages: {
                        ValidationMessage.required: (_) =>
                            l10n.transactionAmountInvalid,
                        ValidationMessage.min: (_) =>
                            l10n.transactionAmountInvalid,
                      },
                    );
                    final button = FilledButton(
                      onPressed: () async {
                        _form.markAllAsTouched();
                        if (_form.invalid || _form.pending) return;
                        final amount =
                            _form.control(SplitAmountControl.total).value
                                as int;
                        final saved = await ref
                            .read(
                              hostSessionManagementControllerProvider(
                                widget.sessionId,
                              ).notifier,
                            )
                            .setSplitAmount(amount);
                        if (saved) _form.reset();
                      },
                      child: Text(l10n.hostManageCalculateAndUpdate),
                    );
                    if (constraints.maxWidth < 440) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          field,
                          const SizedBox(height: AppSpacing.sm),
                          button,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: AppSpacing.sm),
                        button,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.ledger, required this.totalExpenses});
  final PaymentLedger ledger;
  final int totalExpenses;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final total = ledger.stats.totalAmount;
    final paid = ledger.stats.paidAmount;
    final pending = total - paid;
    final net = total - totalExpenses;
    final cells = [
      (l10n.hostManageIncome, total, AppIcons.banknote, AppColors.success),
      (
        l10n.sessionExpensesTotal,
        totalExpenses,
        AppIcons.receipt,
        Theme.of(context).colorScheme.error,
      ),
      (
        l10n.hostManagePaymentPaid,
        paid,
        AppIcons.checkCircle,
        AppColors.success,
      ),
      (
        l10n.hostManagePaymentOutstanding,
        pending,
        AppIcons.clock,
        AppColors.warning,
      ),
    ];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.hostManagePaymentSummary,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.count(
              key: const Key('payment-summary-grid'),
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.8,
              children: [
                for (final cell in cells)
                  _SummaryCell(
                    label: cell.$1,
                    value: Money.compactVnd(cell.$2, locale: locale),
                    icon: cell.$3,
                    color: cell.$4,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            DecoratedBox(
              decoration: BoxDecoration(
                color:
                    (net >= 0
                            ? AppColors.success
                            : Theme.of(context).colorScheme.error)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(AppIcons.calculator),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(l10n.hostManageNetTotal)),
                    Text(
                      Money.vnd(net, locale: locale),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCell extends StatelessWidget {
  const _SummaryCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ),
  );
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.onTap});
  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final name = payment.player?.displayName ?? l10n.hostManageUnknownPlayer;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: payment.player?.clubFeeApplied ?? false
              ? Colors.teal.withValues(alpha: 0.4)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (payment.player?.clubFeeApplied ?? false)
                    Text(
                      payment.player?.clubName ?? l10n.hostManageFixedMembers,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.teal,
                      ),
                    ),
                  if (payment.proofImageUrl?.isNotEmpty ?? false)
                    Text(
                      l10n.hostManageHasProof,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              );
              final amount = Text(
                Money.vnd(payment.amount, locale: locale),
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _PlayerAvatar(payment: payment),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: info),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        amount,
                        PaymentStatusChip(status: payment.status),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  _PlayerAvatar(payment: payment),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: info),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      amount,
                      const SizedBox(height: AppSpacing.xs),
                      PaymentStatusChip(status: payment.status),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PaymentGroupCard extends StatelessWidget {
  const _PaymentGroupCard({
    required this.groupKey,
    required this.payments,
    required this.expanded,
    required this.onToggle,
    required this.onOpen,
    required this.onBulkApprove,
  });
  final String groupKey;
  final List<PaymentRecord> payments;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<PaymentRecord> onOpen;
  final ValueChanged<List<String>> onBulkApprove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final submitted = payments
        .where((item) => item.status == PaymentStatus.submitted)
        .map((item) => item.id)
        .toList(growable: false);
    final total = payments.fold<int>(0, (sum, item) => sum + item.amount);
    return Container(
      key: ValueKey('payment-group-$groupKey'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: AppColors.success.withValues(alpha: 0.08),
            child: InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _PlayerAvatar(payment: payments.first),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                payments.first.player?.displayName ??
                                    l10n.hostManageUnknownPlayer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(l10n.hostManageSlots(payments.length)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              Money.vnd(total, locale: locale),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Icon(
                              expanded
                                  ? AppIcons.chevronUp
                                  : AppIcons.chevronDown,
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (submitted.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => onBulkApprove(submitted),
                          icon: const Icon(AppIcons.checkAll),
                          label: Text(
                            '${l10n.hostManageApprove} (${submitted.length})',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (expanded)
            for (final payment in payments)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: _PaymentCard(
                  payment: payment,
                  onTap: () => onOpen(payment),
                ),
              ),
        ],
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.payment});
  final PaymentRecord payment;
  @override
  Widget build(BuildContext context) {
    final name =
        payment.player?.displayName ??
        AppLocalizations.of(context).hostManageUnknownPlayer;
    final image = payment.player?.userImage;
    return UserAvatar(
      name: name,
      imageUrl: image,
    );
  }
}

class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({required this.status, super.key});
  final PaymentStatus status;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = switch (status) {
      PaymentStatus.pending => AppColors.warning,
      PaymentStatus.submitted => AppColors.info,
      PaymentStatus.approved => AppColors.success,
      PaymentStatus.rejected => Theme.of(context).colorScheme.error,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(l10n, status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _PaymentEmpty extends StatelessWidget {
  const _PaymentEmpty({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.xxl),
    child: Column(
      children: [
        const Icon(AppIcons.receipt, size: 36),
        const SizedBox(height: AppSpacing.sm),
        Text(label, textAlign: TextAlign.center),
      ],
    ),
  );
}

class PaymentLedgerSkeleton extends StatelessWidget {
  const PaymentLedgerSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var section = 0; section < 2; section++) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                for (var row = 0; row < 3; row++) ...[
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    ],
  );
}

class _PaymentFilters {
  const _PaymentFilters(this.status, this.member);
  final PaymentStatus? status;
  final String member;
}

class _PaymentFilterSheet extends StatefulWidget {
  const _PaymentFilterSheet({
    required this.payments,
    required this.status,
    required this.member,
  });
  final List<PaymentRecord> payments;
  final PaymentStatus? status;
  final String member;

  @override
  State<_PaymentFilterSheet> createState() => _PaymentFilterSheetState();
}

class _PaymentFilterSheetState extends State<_PaymentFilterSheet> {
  late PaymentStatus? _status = widget.status;
  late String _member = widget.member;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final clubs = <String, String>{};
    for (final payment in widget.payments) {
      final id = payment.player?.clubId;
      final name = payment.player?.clubName;
      if (id != null && name != null) clubs[id] = name;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.transactionStatusFilter,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<PaymentStatus?>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: l10n.transactionStatusFilter,
            ),
            items: [
              DropdownMenuItem(
                child: Text(
                  l10n.transactionFilterAll,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              for (final status in PaymentStatus.values)
                DropdownMenuItem(
                  value: status,
                  child: Text(
                    _statusLabel(l10n, status),
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _status = value),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _member,
            decoration: InputDecoration(labelText: l10n.hostManageMemberType),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(
                  l10n.transactionFilterAll,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: 'fixed',
                child: Text(
                  l10n.hostManageFixedMembers,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              DropdownMenuItem(
                value: 'regular',
                child: Text(
                  l10n.hostManageRegularMembers,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                ),
              ),
              for (final club in clubs.entries)
                DropdownMenuItem(
                  value: 'club:${club.key}',
                  child: Text(
                    club.value,
                    style: const TextStyle(fontWeight: FontWeight.normal),
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _member = value ?? 'all'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              _PaymentFilters(_status, _member),
            ),
            child: Text(l10n.transactionApply),
          ),
        ],
      ),
    );
  }
}

class SessionPaymentReviewSheet extends ConsumerStatefulWidget {
  const SessionPaymentReviewSheet({
    required this.sessionId,
    required this.payment,
    this.reminder,
    super.key,
  });
  final String sessionId;
  final PaymentRecord payment;
  final PaymentReminder? reminder;

  @override
  ConsumerState<SessionPaymentReviewSheet> createState() =>
      _SessionPaymentReviewSheetState();
}

class _SessionPaymentReviewSheetState
    extends ConsumerState<SessionPaymentReviewSheet> {
  late final FormGroup _form = createPaymentReviewForm(widget.payment);
  bool _busy = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final payment = widget.payment;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: AppReactiveForm(
          formGroup: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.transactionReviewPayment,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        _PlayerAvatar(payment: payment),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            payment.player?.displayName ??
                                l10n.hostManageUnknownPlayer,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        Column(
                          children: [
                            PaymentStatusChip(status: payment.status),
                            if (payment.status == PaymentStatus.pending)
                              TextButton.icon(
                                onPressed: _busy ? null : _remind,
                                icon: const Icon(
                                  AppIcons.notifications,
                                  size: 16,
                                ),
                                label: Text(l10n.transactionRemind),
                              ),
                            if (widget.reminder != null)
                              Text(
                                l10n.hostManageReminderCount(
                                  widget.reminder!.reminderCount,
                                ),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
                  minLines: 2,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.transactionHostNotes,
                  ),
                ),
                if (payment.proofNotes?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(l10n.transactionPlayerNotes),
                  Text(payment.proofNotes!),
                ],
                if (payment.proofImageUrl?.isNotEmpty ?? false) ...[
                  const SizedBox(height: AppSpacing.md),
                  GestureDetector(
                    onTap: () => unawaited(
                      showAppLightbox(
                        context,
                        images: [payment.proofImageUrl!],
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: CachedNetworkImage(
                        imageUrl: payment.proofImageUrl!,
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
                        key: const Key('payment-review-reject'),
                        onPressed: _busy ? null : _reject,
                        icon: const Icon(AppIcons.close),
                        label: Text(l10n.hostManageReject),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        key: const Key('payment-review-approve'),
                        onPressed: _busy ? null : _approve,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(AppIcons.check),
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

  Future<void> _approve() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _busy) return;
    setState(() => _busy = true);
    final ok = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .approvePayment(
          widget.payment.id,
          amount: _form.control(PaymentReviewControl.amount).value as int?,
          paymentMethod:
              _form.control(PaymentReviewControl.method).value
                  as PaymentMethod?,
          hostNotes:
              (_form.control(PaymentReviewControl.notes).value as String?)
                  ?.trim(),
        );
    _finish(ok);
  }

  Future<void> _reject() async {
    if (_busy) return;
    setState(() => _busy = true);
    final notes = (_form.control(PaymentReviewControl.notes).value as String?)
        ?.trim();
    final ok = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .rejectPayment(
          widget.payment.id,
          notes?.isNotEmpty ?? false
              ? notes!
              : AppLocalizations.of(context).transactionRejectFallback,
        );
    _finish(ok);
  }

  Future<void> _remind() async {
    setState(() => _busy = true);
    final ok = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .remindPayment(widget.payment.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? AppLocalizations.of(context).transactionReminderSent
              : AppLocalizations.of(context).transactionReminderFailed,
        ),
      ),
    );
  }

  void _finish(bool ok) {
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }
}

String _statusLabel(AppLocalizations l10n, PaymentStatus status) =>
    switch (status) {
      PaymentStatus.pending => l10n.hostManagePaymentPending,
      PaymentStatus.submitted => l10n.hostManagePaymentSubmitted,
      PaymentStatus.approved => l10n.hostManagePaymentApproved,
      PaymentStatus.rejected => l10n.hostManagePaymentRejected,
    };
