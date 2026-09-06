import 'dart:async';

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
                  _SessionStatusBadge(status: value.status),
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
                ],
              ),
              orElse: SizedBox.shrink,
            ),
          ],
        ),
        bottomNavigationBar: _HostSessionBottomNavBar(
          tabs: [
            _HostNavTab(
              label: l10n.hostManageOverview,
              icon: AppIcons.info,
            ),
            _HostNavTab(
              label: l10n.hostManageRoster,
              icon: AppIcons.users,
            ),
            _HostNavTab(
              label: l10n.hostManageCourts,
              icon: AppIcons.square,
            ),
            _HostNavTab(
              label: l10n.hostManageResults,
              icon: AppIcons.trophy,
            ),
            _HostNavTab(
              label: l10n.hostManagePayments,
              icon: AppIcons.dollarSign,
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
          type: AppConfirmDialogType.submit,
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

class _HostNavTab {
  const _HostNavTab({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

class _HostSessionBottomNavBar extends StatelessWidget {
  const _HostSessionBottomNavBar({required this.tabs});

  final List<_HostNavTab> tabs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final tabController = DefaultTabController.of(context);

    return AnimatedBuilder(
      animation: tabController.animation ?? tabController,
      builder: (context, _) {
        final activeIndex = tabController.indexIsChanging
            ? tabController.index
            : (tabController.animation?.value ?? tabController.index.toDouble())
                  .round();

        return DecoratedBox(
          key: const Key('host-session-bottom-nav'),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: palette.border,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(
                  alpha: theme.brightness == Brightness.light ? 0.05 : 0.25,
                ),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: AppSizes.bottomNavHeight,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(
                      child: _HostNavTabItem(
                        key: ValueKey('host-session-tab-$i'),
                        tab: tabs[i],
                        isActive: activeIndex == i,
                        onTap: () => tabController.animateTo(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HostNavTabItem extends StatelessWidget {
  const _HostNavTabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final _HostNavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    final activeColor = theme.colorScheme.primary;
    final inactiveColor = palette.mutedForeground;

    return Stack(
      children: [
        if (isActive)
          Positioned(
            top: 0,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            height: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: activeColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: activeColor.withValues(alpha: 0.1),
            highlightColor: activeColor.withValues(alpha: 0.05),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                  left: AppSpacing.xxs,
                  right: AppSpacing.xxs,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 20,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isActive ? activeColor : inactiveColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _SessionAction { startSession, endSession, edit, clone, cancel }
