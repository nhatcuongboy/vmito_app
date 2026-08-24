import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
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
        body: Stack(
          fit: StackFit.expand,
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
                key: const Key('host-session-tab-view'),
                children: [
                  HostOverviewTab(
                    key: const Key('host-tab-overview-content'),
                    session: value,
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
      case _SessionAction.startSession:
        await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .startSession();
        return;
      case _SessionAction.endSession:
        await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .endSession();
        return;
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
}

class _SessionHeaderTitle extends StatelessWidget {
  const _SessionHeaderTitle({required this.name, required this.status});

  final String name;
  final SessionStatus status;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          name,
          key: const Key('host-session-title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: AppSpacing.sm),
      _SessionStatusBadge(status: status),
    ],
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
        vertical: 3,
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
