import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/application/hosted_sessions_controller.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_courts_tab.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_payment_ledger_tab.dart';
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
