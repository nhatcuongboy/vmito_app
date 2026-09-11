import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/localization/localized_values.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_bottom_navigation_bar.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/session_edit_modal.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_status_badge.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_courts_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_overview_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_payment_ledger_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_roster_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

class HostSessionManagementScreen extends ConsumerStatefulWidget {
  const HostSessionManagementScreen({
    required this.sessionId,
    this.initialTab = 0,
    super.key,
  });

  final String sessionId;
  final int initialTab;

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
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final contentBackground = Color.alphaBlend(
      palette.muted.withValues(alpha: 0.75),
      theme.colorScheme.surface,
    );
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
      initialIndex: widget.initialTab.clamp(0, 4),
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: theme.colorScheme.surface,
          shape: Border(
            bottom: BorderSide(color: palette.border),
          ),
          title: session.maybeWhen(
            data: (value) => Text(
              value.name,
              key: const Key('host-session-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            orElse: () => Text(l10n.hostManageTitle),
          ),
          actions: [
            session.maybeWhen(
              data: (value) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SessionStatusBadge(status: value.status),
                  const SizedBox(width: AppSpacing.xs),
                  PopupMenuButton<_SessionAction>(
                    key: const Key('host-session-more-menu'),
                    icon: const Icon(AppIcons.moreVert),
                    offset: const Offset(0, 48),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).moreButtonTooltip,
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
                        child: Row(
                          children: [
                            const Icon(AppIcons.edit, size: 18),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                l10n.editSessionTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _SessionAction.clone,
                        child: Row(
                          children: [
                            const Icon(AppIcons.copy, size: 18),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                l10n.cloneSessionTitle,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (value.status == SessionStatus.preparing)
                        PopupMenuItem(
                          value: _SessionAction.cancel,
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.cancel,
                                size: 18,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  l10n.cancelSessionTitle,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              orElse: SizedBox.shrink,
            ),
          ],
        ),
        bottomNavigationBar: _HostSessionBottomNavBar(
          destinations: [
            NavigationDestination(
              key: const ValueKey('host-session-tab-0'),
              label: l10n.hostManageOverview,
              icon: const Icon(AppIcons.info),
            ),
            NavigationDestination(
              key: const ValueKey('host-session-tab-1'),
              label: l10n.hostManageRoster,
              icon: const Icon(AppIcons.users),
            ),
            NavigationDestination(
              key: const ValueKey('host-session-tab-2'),
              label: l10n.hostManageCourts,
              icon: const Icon(AppIcons.square),
            ),
            NavigationDestination(
              key: const ValueKey('host-session-tab-3'),
              label: l10n.hostManageResults,
              icon: const Icon(AppIcons.trophy),
            ),
            NavigationDestination(
              key: const ValueKey('host-session-tab-4'),
              label: l10n.hostManagePayments,
              icon: const Icon(AppIcons.dollarSign),
            ),
          ],
        ),
        body: ColoredBox(
          key: const Key('host-session-content-background'),
          color: contentBackground,
          child: session.when(
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
      ),
    );
  }

  Future<void> _handleAction(Session session, _SessionAction action) async {
    switch (action) {
      case _SessionAction.startSession:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showAppConfirmDialog(
          context,
          title: l10n.startSessionConfirmTitle,
          content: l10n.startSessionConfirm,
          confirmLabel: l10n.startSessionAction,
          confirmKey: const ValueKey('confirm-start-session'),
        );
        if (confirmed != true || !mounted) return;
        await ref
            .read(hostSessionManagementControllerProvider(session.id).notifier)
            .startSession();
        return;
      case _SessionAction.endSession:
        final l10n = AppLocalizations.of(context);
        final confirmed = await showAppConfirmDialog(
          context,
          type: AppConfirmDialogType.destructive,
          title: l10n.endSessionConfirmTitle,
          content: l10n.endSessionConfirm,
          confirmLabel: l10n.endSessionAction,
          confirmKey: const ValueKey('confirm-end-session'),
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
        final confirmed = await showAppConfirmDialog(
          context,
          type: AppConfirmDialogType.destructive,
          title: l10n.cancelSessionTitle,
          content: l10n.cancelSessionConfirm,
          confirmLabel: l10n.cancelSessionAction,
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

class _HostSessionBottomNavBar extends StatelessWidget {
  const _HostSessionBottomNavBar({required this.destinations});

  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final tabController = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: tabController.animation ?? tabController,
      builder: (context, _) {
        final rawIndex = tabController.indexIsChanging
            ? tabController.index
            : (tabController.animation?.value ?? tabController.index.toDouble())
                  .round();
        final maxIndex = destinations.isEmpty ? 0 : destinations.length - 1;
        final activeIndex = rawIndex.clamp(0, maxIndex);

        return AppBottomNavigationBar(
          key: const Key('host-session-bottom-nav'),
          selectedIndex: activeIndex,
          onDestinationSelected: tabController.animateTo,
          destinations: destinations,
        );
      },
    );
  }
}

enum _SessionAction { startSession, endSession, edit, clone, cancel }
