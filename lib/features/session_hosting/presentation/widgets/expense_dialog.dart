import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/input_formatters.dart';
import 'package:vmito_app/features/payment/domain/form/host_payment_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class ExpenseDialog extends ConsumerStatefulWidget {
  const ExpenseDialog({required this.sessionId, this.expense, super.key});
  final String sessionId;
  final SessionExpense? expense;

  @override
  ConsumerState<ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends ConsumerState<ExpenseDialog> {
  late final FormGroup _form = createExpenseForm(widget.expense);
  bool _saving = false;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sessionExpensesTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveTextField<String>(
                key: const ValueKey('expense-name'),
                formControlName: ExpenseControl.name,
                decoration: InputDecoration(labelText: l10n.sessionExpenseName),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      l10n.hostManageExpenseNameRequired,
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ReactiveTextField<int>(
                key: const ValueKey('expense-amount'),
                formControlName: ExpenseControl.amount,
                valueAccessor: CurrencyValueAccessor(),
                inputFormatters: [ThousandsSeparatorFormatter()],
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.sessionExpenseAmount,
                  suffixText: '₫',
                ),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      l10n.transactionAmountInvalid,
                  ValidationMessage.min: (_) => l10n.transactionAmountInvalid,
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.save),
                label: Text(l10n.hostManageSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _form.pending || _saving) return;
    setState(() => _saving = true);
    final saved = await ref
        .read(
          hostSessionManagementControllerProvider(widget.sessionId).notifier,
        )
        .saveExpense(
          expenseId: widget.expense?.id,
          name: (_form.control(ExpenseControl.name).value as String).trim(),
          amount: _form.control(ExpenseControl.amount).value as int,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.pop(context);
  }
}

class ExpenseBatchSheet extends ConsumerStatefulWidget {
  const ExpenseBatchSheet({required this.sessionId, super.key});
  final String sessionId;

  @override
  ConsumerState<ExpenseBatchSheet> createState() => _ExpenseBatchSheetState();
}

class _ExpenseBatchSheetState extends ConsumerState<ExpenseBatchSheet> {
  final List<FormGroup> _forms = [createExpenseForm()];
  bool _saving = false;

  @override
  void dispose() {
    for (final form in _forms) {
      form.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.sessionExpenseAdd,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              for (var index = 0; index < _forms.length; index++) ...[
                AppReactiveForm(
                  formGroup: _forms[index],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ReactiveTextField<String>(
                          formControlName: ExpenseControl.name,
                          decoration: InputDecoration(
                            labelText: l10n.sessionExpenseName,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 120,
                        child: ReactiveTextField<int>(
                          formControlName: ExpenseControl.amount,
                          valueAccessor: CurrencyValueAccessor(),
                          inputFormatters: [ThousandsSeparatorFormatter()],
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: l10n.sessionExpenseAmount,
                          ),
                        ),
                      ),
                      if (_forms.length > 1)
                        IconButton(
                          onPressed: _saving ? null : () => _remove(index),
                          icon: const Icon(AppIcons.delete),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _forms.add(createExpenseForm())),
                icon: const Icon(AppIcons.add),
                label: Text(l10n.hostManageAddAnotherExpense),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.save),
                label: Text(l10n.hostManageSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _remove(int index) {
    _forms.removeAt(index).dispose();
    setState(() {});
  }

  Future<void> _submit() async {
    for (final form in _forms) {
      form.markAllAsTouched();
    }
    final valid = _forms.where((form) => form.valid && !form.pending).toList();
    if (valid.isEmpty || _saving) return;
    setState(() => _saving = true);
    var allSaved = true;
    for (final form in valid) {
      final saved = await ref
          .read(
            hostSessionManagementControllerProvider(widget.sessionId).notifier,
          )
          .saveExpense(
            name: (form.control(ExpenseControl.name).value as String).trim(),
            amount: form.control(ExpenseControl.amount).value as int,
          );
      allSaved = allSaved && saved;
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (allSaved) Navigator.pop(context);
  }
}
