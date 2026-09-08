import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/expense_dialog.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/payment_section_header_style.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

class SessionExpensesCard extends ConsumerWidget {
  const SessionExpensesCard({
    required this.sessionId,
    required this.expenses,
    super.key,
  });

  final String sessionId;
  final AsyncValue<List<SessionExpense>> expenses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: expenses.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(sessionExpensesProvider(sessionId)),
          ),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.sessionExpensesTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('expense-add'),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      useSafeArea: true,
                      builder: (_) => ExpenseBatchSheet(sessionId: sessionId),
                    ),
                    style: PaymentSectionHeaderStyle.actionButtonStyle,
                    icon: const Icon(
                      AppIcons.add,
                      size: PaymentSectionHeaderStyle.actionIconSize,
                    ),
                    label: Text(l10n.sessionExpenseAdd),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Column(
                    children: [
                      const Icon(AppIcons.receipt, size: 36),
                      const SizedBox(height: AppSpacing.sm),
                      Text(l10n.sessionExpensesEmpty),
                    ],
                  ),
                )
              else ...[
                for (final expense in items)
                  _ExpenseTile(
                    sessionId: sessionId,
                    expense: expense,
                  ),
                const Divider(),
                Text(
                  '${l10n.sessionExpensesTotal}: '
                  '${Money.vnd(items.fold<int>(0, (sum, item) => sum + item.amount), locale: Localizations.localeOf(context).languageCode)}',
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpenseTile extends ConsumerWidget {
  const _ExpenseTile({required this.sessionId, required this.expense});
  final String sessionId;
  final SessionExpense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(AppIcons.receipt, color: error),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  Money.vnd(
                    expense.amount,
                    locale: Localizations.localeOf(context).languageCode,
                  ),
                  style: TextStyle(color: error, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.commonEdit,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              useSafeArea: true,
              builder: (_) => ExpenseDialog(
                sessionId: sessionId,
                expense: expense,
              ),
            ),
            icon: const Icon(AppIcons.edit),
          ),
          IconButton(
            tooltip: l10n.commonDelete,
            onPressed: () async {
              final confirmed = await showAppConfirmDialog(
                context,
                type: AppConfirmDialogType.destructive,
                title: l10n.hostManageDeleteExpenseTitle,
                content: l10n.hostManageDeleteExpenseMessage(expense.name),
                confirmLabel: l10n.commonDelete,
              );
              if (confirmed != true) return;
              await ref
                  .read(
                    hostSessionManagementControllerProvider(sessionId).notifier,
                  )
                  .deleteExpense(expense.id);
            },
            icon: const Icon(AppIcons.delete),
          ),
        ],
      ),
    );
  }
}
