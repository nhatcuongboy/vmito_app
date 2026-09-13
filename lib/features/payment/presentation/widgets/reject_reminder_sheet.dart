import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/domain/form/reminder_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/shared/widgets/app_sheet_action_bar.dart';
import 'package:vmito_app/shared/widgets/app_sheet_header.dart';

class RejectReminderSheet extends ConsumerStatefulWidget {
  const RejectReminderSheet({
    super.key,
    required this.reminder,
  });

  final PaymentReminder reminder;

  static Future<bool?> show(
    BuildContext context, {
    required PaymentReminder reminder,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => RejectReminderSheet(reminder: reminder),
    );
  }

  @override
  ConsumerState<RejectReminderSheet> createState() =>
      _RejectReminderSheetState();
}

class _RejectReminderSheetState extends ConsumerState<RejectReminderSheet> {
  late final FormGroup _form = createRejectReminderForm();

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid) return;

    final hostNotes =
        _form.control(RejectReminderControl.hostNotes).value as String?;

    final success = await ref
        .read(paymentRemindersControllerProvider.notifier)
        .reject(widget.reminder.id, hostNotes: hostNotes);

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isBusy = ref.watch(paymentRemindersControllerProvider).isLoading;

    return Padding(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                title: l10n.reminderRejectTitle,
                subtitle: l10n.reminderRejectDescription,
                showCloseButton: false,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSpacing.md),
              ReactiveTextField<String>(
                formControlName: RejectReminderControl.hostNotes,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.reminderRejectReasonPlaceholder,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppSheetActionBar(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                applySafeArea: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isBusy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                        ),
                        onPressed: isBusy ? null : _submit,
                        child: isBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(l10n.reminderReject),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
