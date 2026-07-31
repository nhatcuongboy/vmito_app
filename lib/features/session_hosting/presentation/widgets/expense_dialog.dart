import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ExpenseDialog extends ConsumerStatefulWidget {
  const ExpenseDialog({
    required this.sessionId,
    this.expense,
    super.key,
  });

  final String sessionId;
  final SessionExpense? expense;

  @override
  ConsumerState<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  late final _name = TextEditingController(text: widget.expense?.name);
  late final _amount = TextEditingController(
    text: widget.expense?.amount.toString(),
  );

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.sessionExpensesTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('expense-name'),
            controller: _name,
            decoration: InputDecoration(labelText: l10n.sessionExpenseName),
          ),
          TextField(
            key: const ValueKey('expense-amount'),
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.sessionExpenseAmount,
              suffixText: '₫',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () async {
            final name = _name.text.trim();
            final amount = int.tryParse(_amount.text.trim());
            if (name.isEmpty || amount == null || amount < 0) return;
            final saved = await ref
                .read(
                  hostSessionManagementControllerProvider(
                    widget.sessionId,
                  ).notifier,
                )
                .saveExpense(
                  expenseId: widget.expense?.id,
                  name: name,
                  amount: amount,
                );
            if (saved && context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.hostManageSave),
        ),
      ],
    );
  }
}
