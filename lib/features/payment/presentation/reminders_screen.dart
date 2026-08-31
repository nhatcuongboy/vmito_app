import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/domain/payment.dart';
import 'package:vmito_app/features/payment/presentation/widgets/create_custom_reminder_sheet.dart';
import 'package:vmito_app/features/payment/presentation/widgets/mark_paid_sheet.dart';
import 'package:vmito_app/features/payment/presentation/widgets/reject_reminder_sheet.dart';
import 'package:vmito_app/features/payment/presentation/widgets/reminder_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  String? _actioningReminderId;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRemindAgain(PaymentReminder reminder) async {
    setState(() => _actioningReminderId = reminder.id);
    final l10n = AppLocalizations.of(context);
    try {
      final success = await ref
          .read(paymentRemindersControllerProvider.notifier)
          .remindAgain(reminder.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? l10n.reminderSentSuccessfully
                  : l10n.reminderActionFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actioningReminderId = null);
    }
  }

  Future<void> _handleMarkCollected(PaymentReminder reminder) async {
    setState(() => _actioningReminderId = reminder.id);
    final l10n = AppLocalizations.of(context);
    try {
      final success = await ref
          .read(paymentRemindersControllerProvider.notifier)
          .markCollected(reminder.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? l10n.reminderMarkedCollectedSuccessfully
                  : l10n.reminderActionFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actioningReminderId = null);
    }
  }

  Future<void> _openRejectSheet(PaymentReminder reminder) async {
    final l10n = AppLocalizations.of(context);
    final result = await RejectReminderSheet.show(
      context,
      reminder: reminder,
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderRejectedSuccessfully)),
      );
    }
  }

  Future<void> _openMarkPaidSheet(PaymentReminder reminder) async {
    final l10n = AppLocalizations.of(context);
    final result = await MarkPaidSheet.show(
      context,
      reminder: reminder,
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderMarkedPaidSuccessfully)),
      );
    }
  }

  Future<void> _openCreateReminderSheet() async {
    final l10n = AppLocalizations.of(context);
    final result = await CreateCustomReminderSheet.show(context);
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.reminderSentSuccessfully)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final canCreateReminders =
        user?.isHost == true || user?.isAdmin == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reminderTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.reminderTabToCollect),
            Tab(text: l10n.reminderTabToPay),
          ],
        ),
      ),
      floatingActionButton: canCreateReminders
          ? FloatingActionButton.extended(
              onPressed: _openCreateReminderSheet,
              icon: const Icon(Icons.add),
              label: Text(l10n.reminderCreateReminder),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _ToCollectTab(
            actioningReminderId: _actioningReminderId,
            onRemindAgain: _handleRemindAgain,
            onMarkCollected: _handleMarkCollected,
            onReject: _openRejectSheet,
          ),
          _ToPayTab(
            onMarkPaid: _openMarkPaidSheet,
          ),
        ],
      ),
    );
  }
}

class _ToCollectTab extends ConsumerWidget {
  const _ToCollectTab({
    required this.actioningReminderId,
    required this.onRemindAgain,
    required this.onMarkCollected,
    required this.onReject,
  });

  final String? actioningReminderId;
  final void Function(PaymentReminder) onRemindAgain;
  final void Function(PaymentReminder) onMarkCollected;
  final void Function(PaymentReminder) onReject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncReminders = ref.watch(remindersListProvider('creator'));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(remindersListProvider('creator'));
        await ref.read(remindersListProvider('creator').future);
      },
      child: asyncReminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reminderLoadFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: () => ref.invalidate(remindersListProvider('creator')),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.reminderNoToCollect,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              88, // space for FAB
            ),
            itemCount: reminders.length,
            itemBuilder: (ctx, i) {
              final reminder = reminders[i];
              final isActioning = actioningReminderId == reminder.id;

              Widget? actions;
              if (reminder.status == PaymentReminderStatus.pending) {
                actions = Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isActioning ? null : () => onRemindAgain(reminder),
                      child: isActioning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.reminderRemindAgain),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isActioning
                          ? null
                          : () => onMarkCollected(reminder),
                      child: isActioning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.reminderMarkCollected),
                    ),
                  ],
                );
              } else if (reminder.status ==
                  PaymentReminderStatus.awaitingConfirmation) {
                actions = Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error),
                      ),
                      onPressed: isActioning ? null : () => onReject(reminder),
                      child: Text(l10n.reminderReject),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isActioning
                          ? null
                          : () => onMarkCollected(reminder),
                      child: isActioning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(l10n.reminderApprove),
                    ),
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ReminderCard(
                  reminder: reminder,
                  role: 'creator',
                  actions: actions,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ToPayTab extends ConsumerWidget {
  const _ToPayTab({
    required this.onMarkPaid,
  });

  final void Function(PaymentReminder) onMarkPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final asyncReminders = ref.watch(remindersListProvider('recipient'));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(remindersListProvider('recipient'));
        await ref.read(remindersListProvider('recipient').future);
      },
      child: asyncReminders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.reminderLoadFailed,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.tonal(
                onPressed: () =>
                    ref.invalidate(remindersListProvider('recipient')),
                child: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
        data: (reminders) {
          if (reminders.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.5,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.reminderNoToPay,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: reminders.length,
            itemBuilder: (ctx, i) {
              final reminder = reminders[i];

              Widget? actions;
              if (reminder.status == PaymentReminderStatus.pending) {
                actions = Row(
                  children: [
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => onMarkPaid(reminder),
                      child: Text(l10n.reminderMarkPaid),
                    ),
                  ],
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: ReminderCard(
                  reminder: reminder,
                  role: 'recipient',
                  actions: actions,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
