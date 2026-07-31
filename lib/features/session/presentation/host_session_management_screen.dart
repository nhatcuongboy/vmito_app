import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/live_session/application/live_session_controller.dart';
import 'package:vmito_app/features/session/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session/application/hosted_sessions_controller.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/payment.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/features/session/presentation/widgets/court_tile.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class HostSessionManagementScreen extends ConsumerStatefulWidget {
  const HostSessionManagementScreen({required this.sessionId, super.key});

  final String sessionId;

  @override
  ConsumerState<HostSessionManagementScreen> createState() =>
      _HostSessionManagementScreenState();
}

class _HostSessionManagementScreenState
    extends ConsumerState<HostSessionManagementScreen>
    with WidgetsBindingObserver {
  String get sessionId => widget.sessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    ref
      ..invalidate(sessionDetailProvider(sessionId))
      ..invalidate(paymentLedgerProvider(sessionId))
      ..invalidate(sessionExpensesProvider(sessionId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionDetailProvider(sessionId));
    final mutation = ref.watch(
      hostSessionManagementControllerProvider(sessionId),
    );
    ref
      ..watch(liveSessionRealtimeProvider(sessionId))
      ..listen(hostSessionManagementControllerProvider(sessionId), (_, next) {
        if (next.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.hostManageActionFailed)),
          );
        }
      });

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.hostManageTitle),
          actions: [
            session.maybeWhen(
              data: (value) => PopupMenuButton<_SessionAction>(
                onSelected: (action) => _handleAction(value, action),
                itemBuilder: (context) => [
                  if (value.status == SessionStatus.preparing)
                    PopupMenuItem(
                      value: _SessionAction.edit,
                      child: Text(l10n.editSessionTitle),
                    ),
                  PopupMenuItem(
                    value: _SessionAction.clone,
                    child: Text(l10n.cloneSessionTitle),
                  ),
                  if (value.status == SessionStatus.preparing)
                    PopupMenuItem(
                      value: _SessionAction.cancel,
                      child: Text(l10n.cancelSessionTitle),
                    ),
                ],
              ),
              orElse: SizedBox.shrink,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.hostManageCourts),
              Tab(text: l10n.hostManageRoster),
              Tab(text: l10n.hostManagePayments),
            ],
          ),
        ),
        body: Stack(
          children: [
            session.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => AppErrorView(
                error: error,
                onRetry: () => ref.invalidate(
                  sessionDetailProvider(sessionId),
                ),
              ),
              data: (value) => TabBarView(
                children: [
                  HostCourtsTab(session: value),
                  HostRosterTab(session: value),
                  HostPaymentLedgerTab(session: value),
                ],
              ),
            ),
            if (mutation.isLoading)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(Session session, _SessionAction action) async {
    switch (action) {
      case _SessionAction.edit:
        await context.push(AppRoutes.editSession(session.id));
        ref.invalidate(sessionDetailProvider(session.id));
        return;
      case _SessionAction.clone:
        await context.push(AppRoutes.cloneSession(session.id));
        return;
      case _SessionAction.cancel:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.cancelSessionTitle),
            content: Text(l10n.cancelSessionConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.cancelSessionAction),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final cancelled = await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .cancelSession();
        if (!cancelled || !mounted) return;
        ref.invalidate(hostedSessionsProvider);
        context.go(AppRoutes.home);
        return;
    }
  }
}

enum _SessionAction { edit, clone, cancel }

class HostCourtsTab extends ConsumerWidget {
  const HostCourtsTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (session.courts.isEmpty) {
      return Center(child: Text(l10n.liveNoCourts));
    }
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionDetailProvider(session.id).future),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: session.orderedCourts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          if (index == 0) return SessionRunCard(session: session);
          return HostCourtCard(
            session: session,
            court: session.orderedCourts[index - 1],
          );
        },
      ),
    );
  }
}

class SessionRunCard extends ConsumerWidget {
  const SessionRunCard({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (session.status == SessionStatus.preparing)
              FilledButton.icon(
                key: const ValueKey('start-session'),
                onPressed: controller.startSession,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(l10n.hostManageStartSession),
              )
            else if (session.status == SessionStatus.inProgress)
              OutlinedButton.icon(
                key: const ValueKey('end-session'),
                onPressed: controller.endSession,
                icon: const Icon(Icons.stop_rounded),
                label: Text(l10n.hostManageEndSession),
              ),
          ],
        ),
      ),
    );
  }
}

class HostCourtCard extends ConsumerWidget {
  const HostCourtCard({required this.session, required this.court, super.key});

  final Session session;
  final Court court;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    final canAssign = session.status.isLive && !court.isPlaying;
    final hasPlayers = court.currentPlayers.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CourtTile(court: court),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                if (canAssign && !hasPlayers)
                  FilledButton.tonalIcon(
                    key: ValueKey('assign-${court.id}'),
                    onPressed: () async {
                      final players = await showDialog<List<String>>(
                        context: context,
                        builder: (_) => PlayerSelectionDialog(
                          players: session.players
                              .where(
                                (player) =>
                                    player.status == PlayerStatus.waiting,
                              )
                              .toList(),
                        ),
                      );
                      if (players != null) {
                        await controller.selectPlayers(court.id, players);
                      }
                    },
                    icon: const Icon(Icons.group_add_outlined),
                    label: Text(l10n.hostManageAssign),
                  ),
                if (canAssign && hasPlayers)
                  OutlinedButton(
                    onPressed: () => controller.deselectPlayers(court.id),
                    child: Text(l10n.hostManageClearCourt),
                  ),
                if (court.status == CourtStatus.ready)
                  FilledButton.icon(
                    key: ValueKey('start-${court.id}'),
                    onPressed: () => controller.startMatch(court.id),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(l10n.hostManageStartMatch),
                  ),
                if (court.isPlaying)
                  FilledButton.icon(
                    key: ValueKey('end-${court.id}'),
                    onPressed: () => controller.endMatch(court.id),
                    icon: const Icon(Icons.stop_rounded),
                    label: Text(l10n.hostManageEndMatch),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerSelectionDialog extends StatefulWidget {
  const PlayerSelectionDialog({required this.players, super.key});

  final List<SessionPlayer> players;

  @override
  State<PlayerSelectionDialog> createState() => _PlayerSelectionDialogState();
}

class _PlayerSelectionDialogState extends State<PlayerSelectionDialog> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final valid = _selected.length == 2 || _selected.length == 4;
    return AlertDialog(
      title: Text(l10n.hostManageAssign),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.hostManageChooseTwoOrFour),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final player in widget.players)
                    CheckboxListTile(
                      value: _selected.contains(player.id),
                      title: Text(l10n.playerName(player)),
                      subtitle: Text(
                        l10n.playerNumbered(player.playerNumber ?? 0),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          if (_selected.length < 4) _selected.add(player.id);
                        } else {
                          _selected.remove(player.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('confirm-player-selection'),
          onPressed: valid
              ? () => Navigator.pop(context, _selected.toList())
              : null,
          child: Text(l10n.hostManageAssign),
        ),
      ],
    );
  }
}

class HostRosterTab extends ConsumerWidget {
  const HostRosterTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final roster = [...session.players]
      ..sort((a, b) {
        if (a.isWaiting != b.isWaiting) return a.isWaiting ? -1 : 1;
        return b.currentWaitTime.compareTo(a.currentWaitTime);
      });
    final controller = ref.read(
      hostSessionManagementControllerProvider(session.id).notifier,
    );
    return RefreshIndicator(
      onRefresh: () => ref.refresh(sessionDetailProvider(session.id).future),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.hostManagePendingApprovals,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (session.pendingPlayers.isEmpty)
            Text(l10n.hostManageNoPending)
          else
            for (final player in session.pendingPlayers)
              Card(
                child: ListTile(
                  title: Text(l10n.playerName(player)),
                  subtitle: player.phone == null ? null : Text(player.phone!),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        tooltip: l10n.hostManageReject,
                        onPressed: () => controller.updateRegistration(
                          player.id,
                          approved: false,
                        ),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton.filled(
                        tooltip: l10n.hostManageApprove,
                        onPressed: () => controller.updateRegistration(
                          player.id,
                          approved: true,
                        ),
                        icon: const Icon(Icons.check_rounded),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.hostManageApprovedPlayers,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (roster.isEmpty)
            Text(l10n.hostManageNoPlayers)
          else
            for (final player in roster)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${player.playerNumber ?? '•'}'),
                  ),
                  title: Text(l10n.playerName(player)),
                  subtitle: Text(
                    player.isWaiting
                        ? '${_playerStatus(l10n, player.status)} · '
                              '${l10n.waitingTimeLabel}: '
                              '${Dates.waitMinutes(player.currentWaitTime, locale: locale)}'
                        : _playerStatus(l10n, player.status),
                  ),
                  trailing: Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      IconButton(
                        tooltip: player.status == PlayerStatus.inactive
                            ? l10n.hostManageCheckIn
                            : l10n.hostManageCheckOut,
                        onPressed: player.isOnCourt
                            ? null
                            : () => controller.toggleCheckIn(player.id),
                        icon: Icon(
                          player.status == PlayerStatus.inactive
                              ? Icons.how_to_reg_outlined
                              : Icons.person_off_outlined,
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.hostManageRemove,
                        onPressed: player.isOnCourt
                            ? null
                            : () => controller.removePlayer(player.id),
                        icon: const Icon(Icons.person_remove_outlined),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  String _playerStatus(AppLocalizations l10n, PlayerStatus status) =>
      switch (status) {
        PlayerStatus.waiting => l10n.playerStatusWaiting,
        PlayerStatus.playing => l10n.playerStatusPlaying,
        PlayerStatus.finished => l10n.playerStatusFinished,
        PlayerStatus.ready => l10n.playerStatusReady,
        PlayerStatus.inactive => l10n.playerStatusInactive,
      };
}

class HostPaymentLedgerTab extends ConsumerWidget {
  const HostPaymentLedgerTab({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(paymentLedgerProvider(session.id));
    final settings = ref.watch(paymentSettingsProvider);
    final expenses = ref.watch(sessionExpensesProvider(session.id));
    return RefreshIndicator(
      onRefresh: () async {
        ref
          ..invalidate(paymentLedgerProvider(session.id))
          ..invalidate(paymentSettingsProvider)
          ..invalidate(sessionExpensesProvider(session.id));
        await ref.read(paymentLedgerProvider(session.id).future);
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          PaymentSettingsCard(sessionId: session.id, settings: settings),
          const SizedBox(height: AppSpacing.md),
          ledger.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => AppErrorView(
              error: error,
              onRetry: () => ref.invalidate(
                paymentLedgerProvider(session.id),
              ),
            ),
            data: (value) => PaymentLedgerView(
              session: session,
              ledger: value,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SessionExpensesCard(sessionId: session.id, expenses: expenses),
        ],
      ),
    );
  }
}

class PaymentSettingsCard extends ConsumerWidget {
  const PaymentSettingsCard({
    required this.sessionId,
    required this.settings,
    super.key,
  });

  final String sessionId;
  final AsyncValue<List<HostPaymentSettings>> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: settings.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(paymentSettingsProvider),
          ),
          data: (items) {
            HostPaymentSettings? current;
            for (final item in items) {
              current ??= item;
              if (item.isDefault) {
                current = item;
                break;
              }
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.hostManagePaymentSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (current != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  if (items.length > 1)
                    DropdownButtonFormField<String>(
                      initialValue: current.id,
                      decoration: InputDecoration(
                        labelText: l10n.hostManagePaymentSettings,
                      ),
                      items: [
                        for (final item in items)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(
                              '${item.bankName ?? '—'} · '
                              '${item.bankAccountNumber ?? '—'}',
                            ),
                          ),
                      ],
                      onChanged: (id) async {
                        if (id != null && id != current?.id) {
                          await ref
                              .read(
                                hostSessionManagementControllerProvider(
                                  sessionId,
                                ).notifier,
                              )
                              .setDefaultSettings(id);
                        }
                      },
                    ),
                  Text(current.bankName ?? '—'),
                  Text(current.bankAccountNumber ?? '—'),
                  Text(current.accountHolderName ?? '—'),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppSpacing.xs,
                  children: [
                    if (current != null)
                      IconButton(
                        tooltip: l10n.hostManageAddSettings,
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => PaymentSettingsDialog(
                            sessionId: sessionId,
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    if (current != null)
                      IconButton(
                        tooltip: l10n.hostManageDeleteSettings,
                        onPressed: () => ref
                            .read(
                              hostSessionManagementControllerProvider(
                                sessionId,
                              ).notifier,
                            )
                            .deleteSettings(current!.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => PaymentSettingsDialog(
                          sessionId: sessionId,
                          current: current,
                        ),
                      ),
                      icon: const Icon(Icons.account_balance_outlined),
                      label: Text(
                        current == null
                            ? l10n.hostManageAddSettings
                            : l10n.hostManageEditSettings,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PaymentSettingsDialog extends ConsumerStatefulWidget {
  const PaymentSettingsDialog({
    required this.sessionId,
    this.current,
    super.key,
  });

  final String sessionId;
  final HostPaymentSettings? current;

  @override
  ConsumerState<PaymentSettingsDialog> createState() =>
      _PaymentSettingsDialogState();
}

class _PaymentSettingsDialogState extends ConsumerState<PaymentSettingsDialog> {
  late final _bank = TextEditingController(text: widget.current?.bankName);
  late final _number = TextEditingController(
    text: widget.current?.bankAccountNumber,
  );
  late final _holder = TextEditingController(
    text: widget.current?.accountHolderName,
  );

  @override
  void dispose() {
    _bank.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.hostManagePaymentSettings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _bank,
            decoration: InputDecoration(labelText: l10n.hostManageBank),
          ),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.hostManageAccountNumber,
            ),
          ),
          TextField(
            controller: _holder,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.hostManageAccountHolder,
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
            final saved = await ref
                .read(
                  hostSessionManagementControllerProvider(
                    widget.sessionId,
                  ).notifier,
                )
                .saveSettings(
                  id: widget.current?.id,
                  bankName: _bank.text.trim(),
                  accountNumber: _number.text.trim(),
                  accountHolder: _holder.text.trim(),
                );
            if (saved && context.mounted) Navigator.pop(context);
          },
          child: Text(l10n.hostManageSave),
        ),
      ],
    );
  }
}

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
                    icon: const Icon(Icons.add_rounded),
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
                          icon: const Icon(Icons.edit_outlined),
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
                          icon: const Icon(Icons.delete_outline_rounded),
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
            _SummaryChip(
              label: l10n.hostManagePaymentTotal,
              value: Money.vnd(ledger.stats.totalAmount, locale: locale),
            ),
            _SummaryChip(
              label: l10n.hostManagePaymentPaid,
              value: Money.vnd(ledger.stats.paidAmount, locale: locale),
            ),
            _SummaryChip(
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

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(label: Text('$label: $value'));
}
