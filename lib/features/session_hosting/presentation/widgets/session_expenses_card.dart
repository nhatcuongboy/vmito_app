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
import 'package:vmito_app/l10n/app_localizations.dart';

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
    final locale = Localizations.localeOf(context).languageCode;
    return Card(
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
                  IconButton(
                    tooltip: l10n.sessionExpenseAdd,
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ExpenseDialog(sessionId: sessionId),
                    ),
                    icon: const Icon(AppIcons.add),
                  ),
                ],
              ),
              if (items.isEmpty)
                Text(l10n.sessionExpensesEmpty)
              else ...[
                for (final expense in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(expense.name),
                    subtitle: Text(Money.vnd(expense.amount, locale: locale)),
                    trailing: Wrap(
                      spacing: AppSpacing.xs,
                      children: [
                        IconButton(
                          tooltip: l10n.hostManageEditSettings,
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => ExpenseDialog(
                              sessionId: sessionId,
                              expense: expense,
                            ),
                          ),
                          icon: const Icon(AppIcons.edit),
                        ),
                        IconButton(
                          tooltip: l10n.hostManageRemove,
                          onPressed: () => ref
                              .read(
                                hostSessionManagementControllerProvider(
                                  sessionId,
                                ).notifier,
                              )
                              .deleteExpense(expense.id),
                          icon: const Icon(AppIcons.delete),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Text(
                  '${l10n.sessionExpensesTotal}: '
                  '${Money.vnd(items.fold<int>(0, (sum, item) => sum + item.amount), locale: locale)}',
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
