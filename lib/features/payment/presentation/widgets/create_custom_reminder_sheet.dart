import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/widgets/app_reactive_form.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/user_avatar.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/domain/form/reminder_forms.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class CreateCustomReminderSheet extends ConsumerStatefulWidget {
  const CreateCustomReminderSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => const CreateCustomReminderSheet(),
    );
  }

  @override
  ConsumerState<CreateCustomReminderSheet> createState() =>
      _CreateCustomReminderSheetState();
}

class _CreateCustomReminderSheetState
    extends ConsumerState<CreateCustomReminderSheet> {
  late final FormGroup _form = createCustomReminderForm();
  PaymentReminderUser? _selectedUser;
  String _searchQuery = '';
  Timer? _debounce;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _form.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  void _selectUser(PaymentReminderUser user) {
    setState(() {
      _selectedUser = user;
      _searchQuery = '';
      _searchController.clear();
      _form.control(CreateCustomReminderControl.recipientUserId).value =
          user.id;
      _form.control(CreateCustomReminderControl.recipientName).value =
          user.name;
    });
  }

  void _clearSelectedUser() {
    setState(() {
      _selectedUser = null;
      _form.control(CreateCustomReminderControl.recipientUserId).value = null;
      _form.control(CreateCustomReminderControl.recipientName).value = null;
    });
  }

  Future<void> _submit() async {
    _form.markAllAsTouched();
    if (_form.invalid || _selectedUser == null) return;

    final recipientUserId =
        _form.control(CreateCustomReminderControl.recipientUserId).value
            as String;
    final amount =
        _form.control(CreateCustomReminderControl.amount).value as int;
    final note =
        _form.control(CreateCustomReminderControl.note).value as String;

    final success = await ref
        .read(paymentRemindersControllerProvider.notifier)
        .createCustomReminder(
          recipientUserId: recipientUserId,
          amount: amount,
          note: note,
        );

    if (mounted && success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isBusy = ref.watch(paymentRemindersControllerProvider).isLoading;

    final searchResults = ref.watch(
      reminderUserSearchProvider(_searchQuery),
    );

    return Padding(
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
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.reminderCreateCustomReminder,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Recipient Selector
              Text(
                l10n.reminderRecipient,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_selectedUser != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Row(
                    children: [
                      UserAvatar(
                        name: _selectedUser!.name,
                        imageUrl: _selectedUser!.image,
                        gender: _selectedUser!.gender,
                        size: 36,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedUser!.name,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedUser!.email != null)
                              Text(
                                _selectedUser!.email!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSelectedUser,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.reminderSearchUserPlaceholder,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
                if (_searchQuery.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                    child: searchResults.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Center(
                          child: Text(
                            l10n.reminderActionFailed,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                      data: (users) {
                        if (users.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Center(
                              child: Text(
                                l10n.reminderNoResults,
                                style: TextStyle(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: users.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final u = users[i];
                            return ListTile(
                              dense: true,
                              leading: UserAvatar(
                                name: u.name,
                                imageUrl: u.image,
                                gender: u.gender,
                                size: 32,
                              ),
                              title: Text(
                                u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: u.email != null
                                  ? Text(
                                      u.email!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              onTap: () => _selectUser(u),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ],
              const SizedBox(height: AppSpacing.md),

              // Amount
              Text(
                l10n.reminderAmount,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveTextField<int>(
                formControlName: CreateCustomReminderControl.amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixText: '₫',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                ),
                validationMessages: {
                  ValidationMessage.required: (_) =>
                      l10n.reminderAmountRequired,
                  ValidationMessage.min: (_) => l10n.reminderAmountRequired,
                  ValidationMessage.number: (_) => l10n.reminderAmountRequired,
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Note
              Text(
                l10n.reminderNote,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              ReactiveTextField<String>(
                formControlName: CreateCustomReminderControl.note,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: l10n.reminderCustomReminderNotePlaceholder,
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.all(AppSpacing.sm),
                ),
                validationMessages: {
                  ValidationMessage.required: (_) => l10n.reminderNoteRequired,
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
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
                        : Text(l10n.commonSubmit),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
