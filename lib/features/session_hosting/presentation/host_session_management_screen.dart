import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_edit_modal.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_courts_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_overview_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_payment_ledger_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_roster_tab.dart';
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
      ..invalidate(matchHistoryProvider(sessionId))
      ..invalidate(paymentLedgerProvider(sessionId))
      ..invalidate(sessionExpensesProvider(sessionId))
      ..invalidate(sessionFeeConfigProvider(sessionId))
      ..invalidate(paymentSettingsProvider)
      ..invalidate(paymentRemindersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionDetailProvider(sessionId));
    ref
      ..watch(liveSessionRealtimeProvider(sessionId))
      ..listen(hostSessionManagementControllerProvider(sessionId), (_, next) {
        if (next.hasError) {
          final error = next.error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.hostSessionManagementError(error)),
            ),
          );
        }
      });

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: session.maybeWhen(
            data: (value) => _SessionHeaderTitle(
              name: value.name,
              status: value.status,
            ),
            orElse: () => Text(l10n.hostManageTitle),
          ),
          actions: [
            session.maybeWhen(
              data: (value) => PopupMenuButton<_SessionAction>(
                key: const Key('host-session-more-menu'),
                icon: const Icon(AppIcons.moreVert),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                onSelected: (action) => _handleAction(value, action),
                itemBuilder: (context) => [
                  if (value.status == SessionStatus.preparing)
                    PopupMenuItem(
                      value: _SessionAction.startSession,
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.play,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              l10n.hostManageStartSession,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (value.status == SessionStatus.inProgress)
                    PopupMenuItem(
                      value: _SessionAction.endSession,
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.stop,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              l10n.hostManageEndSession,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
          bottom: _HostManagementTabBar(
            labels: [
              l10n.hostManageOverview,
              l10n.hostManageRoster,
              l10n.hostManageCourts,
              l10n.hostManageResults,
              l10n.hostManagePayments,
            ],
          ),
        ),
        body: session.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(
              sessionDetailProvider(sessionId),
            ),
          ),
          data: (value) => TabBarView(
            key: const Key('host-session-tab-view'),
            children: [
              HostOverviewTab(
                key: const Key('host-tab-overview-content'),
                session: value,
                onEdit: () => unawaited(_editSession(value)),
              ),
              HostRosterTab(
                key: const Key('host-tab-roster-content'),
                session: value,
              ),
              HostCourtsTab(
                key: const Key('host-tab-courts-content'),
                session: value,
              ),
              HostResultsTab(
                key: const Key('host-tab-results-content'),
                session: value,
              ),
              HostPaymentLedgerTab(
                key: const Key('host-tab-payments-content'),
                session: value,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAction(Session session, _SessionAction action) async {
    switch (action) {
      case _SessionAction.startSession:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.startSessionConfirmTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Text(l10n.startSessionConfirm),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('confirm-start-session'),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.startSessionAction),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .startSession();
        return;
      case _SessionAction.endSession:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.endSessionConfirmTitle),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Text(l10n.endSessionConfirm),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                key: const ValueKey('confirm-end-session'),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.endSessionAction),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .endSession();
        return;
      case _SessionAction.edit:
        await _editSession(session);
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
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 320),
              child: Text(l10n.cancelSessionConfirm),
            ),
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
        await ref
            .read(
              mySessionsControllerProvider(MySessionScope.hosted).notifier,
            )
            .refreshIfLoaded();
        if (!mounted) return;
        context.go(AppRoutes.browseSessions);
        return;
    }
  }

  Future<void> _editSession(Session session) async {
    final updated = await showSessionEditModal(context, session: session);
    if (updated == null || !mounted) return;
    ref.invalidate(sessionDetailProvider(session.id));
  }
}

class _SessionHeaderTitle extends StatelessWidget {
  const _SessionHeaderTitle({required this.name, required this.status});

  final String name;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(
        name,
        key: const Key('host-session-title'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      );

      if (constraints.maxWidth >= 480) {
        return Row(
          children: [
            Expanded(child: title),
            const SizedBox(width: AppSpacing.md),
            _SessionStatusBadge(status: status),
          ],
        );
      }

      return Column(
        key: const Key('host-session-header-compact'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          const SizedBox(height: AppSpacing.xs),
          _SessionStatusBadge(status: status),
        ],
      );
    },
  );
}

class _SessionStatusBadge extends StatelessWidget {
  const _SessionStatusBadge({required this.status});

  final SessionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPalette>()!;
    final (label, color) = switch (status) {
      SessionStatus.preparing => (
        l10n.sessionStatusPreparing,
        palette.mutedForeground,
      ),
      SessionStatus.inProgress => (
        l10n.sessionStatusInProgress,
        palette.success,
      ),
      SessionStatus.finished => (
        l10n.sessionStatusFinished,
        palette.mutedForeground,
      ),
      SessionStatus.cancelled => (l10n.sessionStatusCancelled, palette.warning),
    };

    return Container(
      key: const Key('host-session-status-badge'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _HostManagementTabBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _HostManagementTabBar({required this.labels});

  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(49);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.4);
      final contentWidth = math
          .max(
            constraints.maxWidth,
            340 * textScale,
          )
          .toDouble();
      return SingleChildScrollView(
        key: const Key('host-session-tabs-scroll'),
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: contentWidth,
          child: TabBar(
            key: const Key('host-session-tabs'),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: [
              for (var index = 0; index < labels.length; index++)
                Tab(
                  key: ValueKey('host-session-tab-$index'),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(labels[index], maxLines: 1),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

enum _SessionAction { startSession, endSession, edit, clone, cancel }
