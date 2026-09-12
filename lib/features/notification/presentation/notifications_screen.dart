import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/web/app_web_view.dart';
import 'package:vmito_app/core/widgets/app_tab_bar.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_content.dart';
import 'package:vmito_app/features/notification/domain/notification_panel_item.dart';
import 'package:vmito_app/features/notification/domain/notification_routing.dart';
import 'package:vmito_app/features/notification/presentation/widgets/notification_approval_item.dart';
import 'package:vmito_app/features/notification/presentation/widgets/notification_list_item.dart';
import 'package:vmito_app/features/notification/presentation/widgets/notification_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_dialog.dart';

enum _NotificationPanelTab { all, pending, information }

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _maxContentWidth = 720.0;
  final _scrollController = ScrollController();
  _NotificationPanelTab _selectedTab = _NotificationPanelTab.all;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(notificationControllerProvider.notifier).load());
    });
  }

  void _onScroll() {
    if (_selectedTab == _NotificationPanelTab.pending) return;
    if (_scrollController.position.extentAfter < 500) {
      unawaited(ref.read(notificationControllerProvider.notifier).loadMore());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationControllerProvider);
    final controller = ref.read(notificationControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    final panelItems = _panelItemsForTab(state);

    ref.listen(notificationControllerProvider, (previous, next) {
      if (next.error != null &&
          next.error != previous?.error &&
          next.panelItems.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.notificationActionFailed)),
        );
        controller.clearError();
      }
    });

    return DefaultTabController(
      length: _NotificationPanelTab.values.length,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const BackButtonIcon(),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(AppRoutes.home);
              }
            },
          ),
          title: Text(l10n.notificationsTitle),
          actions: [
            TextButton.icon(
              key: const Key('notification-mark-all-read'),
              onPressed: state.unreadCount == 0 || state.isMarkingAll
                  ? null
                  : () => unawaited(controller.markAllRead()),
              icon: state.isMarkingAll
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.checkAll, size: 18),
              label: Text(l10n.notificationsMarkAllRead),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          bottom: AppTabBar(
            onTap: (index) => setState(
              () => _selectedTab = _NotificationPanelTab.values[index],
            ),
            tabs: [
              Tab(
                key: const Key('notification-tab-all'),
                text: l10n.notificationsTabAll,
              ),
              Tab(
                key: const Key('notification-tab-pending'),
                text:
                    '${l10n.notificationPending} (${state.pendingApprovalCount})',
              ),
              Tab(
                key: const Key('notification-tab-information'),
                text: l10n.notificationsTabInformation,
              ),
            ],
          ),
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalInset = constraints.maxWidth > _maxContentWidth
                ? (constraints.maxWidth - _maxContentWidth) / 2
                : 0.0;
            if (state.isLoading && !state.hasLoaded && panelItems.isEmpty) {
              return ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                itemCount: 5,
                itemBuilder: (_, _) => const NotificationSkeleton(),
              );
            }
            if (state.error != null &&
                panelItems.isEmpty &&
                state.hasLoaded &&
                !state.hasSuccessfulLoad) {
              return RefreshIndicator(
                onRefresh: controller.load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: horizontalInset),
                  children: [
                    SizedBox(height: constraints.maxHeight * 0.2),
                    Icon(
                      AppIcons.error,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      l10n.notificationLoadFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: controller.load,
                        icon: const Icon(AppIcons.refresh),
                        label: Text(l10n.commonRetry),
                      ),
                    ),
                  ],
                ),
              );
            }

            final extraLoadingItems = state.isLoadingMore ? 3 : 0;
            return RefreshIndicator(
              onRefresh: controller.load,
              child: ListView.builder(
                key: const Key('notification-panel-list'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalInset,
                  0,
                  horizontalInset,
                  AppSpacing.lg,
                ),
                itemCount:
                    (panelItems.isEmpty ? 1 : panelItems.length) +
                    extraLoadingItems,
                itemBuilder: (context, index) {
                  if (panelItems.isEmpty) {
                    return _EmptyNotifications(
                      minHeight: constraints.maxHeight * 0.58,
                      message: _selectedTab == _NotificationPanelTab.pending
                          ? l10n.notificationApprovalsEmpty
                          : l10n.notificationsEmpty,
                    );
                  }
                  if (index >= panelItems.length) {
                    return const NotificationSkeleton();
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPanelItem(panelItems[index], state, controller),
                      const Divider(height: 1),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  List<NotificationPanelItem> _panelItemsForTab(NotificationState state) =>
      switch (_selectedTab) {
        _NotificationPanelTab.all => state.panelItems,
        _NotificationPanelTab.pending =>
          state.panelItems
              .where((item) => item is! RegularNotificationItem)
              .toList(growable: false),
        _NotificationPanelTab.information =>
          state.panelItems.whereType<RegularNotificationItem>().toList(
            growable: false,
          ),
      };

  Widget _buildPanelItem(
    NotificationPanelItem item,
    NotificationState state,
    NotificationController controller,
  ) => switch (item) {
    RegularNotificationItem(:final notification) => NotificationListItem(
      notification: notification,
      deleting: state.deletingNotificationId == notification.id,
      onTap: () => unawaited(_openNotification(notification, controller)),
      onMarkAsRead: notification.isRead
          ? null
          : () => unawaited(controller.markRead(notification)),
      onDelete: () => unawaited(_confirmDelete(notification, controller)),
    ),
    SessionApprovalItem() => SessionApprovalListItem(
      item: item,
      busy: state.actingSessionGroupKey == item.request.groupKey,
      onTap: () => context.push(
        AppRoutes.sessionJoinRequestDetail(
          item.request.sessionId,
          item.request.id,
        ),
      ),
      onDecision: (approved) => unawaited(
        _decideSession(item, approved: approved, controller: controller),
      ),
    ),
    ClubApprovalItem(:final request) => ClubApprovalListItem(
      item: item,
      busy: state.actingClubRequestId == request.id,
      onTap: () => context.push(
        AppRoutes.clubJoinRequestDetail(request.clubId, request.id),
      ),
      onDecision: (approved) => unawaited(
        _decideClub(item, approved: approved, controller: controller),
      ),
    ),
    VenueApprovalItem() => VenueApprovalListItem(
      item: item,
      onTap: () => unawaited(_openVenueApproval(item)),
    ),
  };

  Future<void> _decideSession(
    SessionApprovalItem item, {
    required bool approved,
    required NotificationController controller,
  }) async {
    final success = await controller.decideSessionRequest(
      item,
      approved: approved,
    );
    if (!mounted || !success) return;
    _showDecisionResult(approved);
    if (approved) {
      await context.push(
        AppRoutes.manageSession(item.request.sessionId, tab: 'roster'),
      );
    }
  }

  Future<void> _decideClub(
    ClubApprovalItem item, {
    required bool approved,
    required NotificationController controller,
  }) async {
    final success = await controller.decideClubRequest(
      item.request,
      approved: approved,
    );
    if (!mounted || !success) return;
    _showDecisionResult(approved);
  }

  void _showDecisionResult(bool approved) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          approved
              ? l10n.notificationApproveSuccess
              : l10n.notificationRejectSuccess,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    AppNotification notification,
    NotificationController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final content = getNotificationDisplayText(notification, l10n);
    final confirmed = await showAppConfirmDialog(
      context,
      type: AppConfirmDialogType.destructive,
      title: l10n.notificationDeleteConfirmTitle,
      content: l10n.notificationDeleteConfirmDescription(content.displayTitle),
      confirmLabel: l10n.notificationDelete,
    );
    if (confirmed == true) await controller.delete(notification.id);
  }

  Future<void> _openNotification(
    AppNotification notification,
    NotificationController controller,
  ) async {
    await controller.markRead(notification);
    if (!mounted) return;
    final route = getNotificationTargetRoute(
      notification,
      userRole: ref.read(currentUserProvider)?.role,
    );
    if (route != null) await context.push(route);
  }

  Future<void> _openVenueApproval(VenueApprovalItem item) {
    final locale = Localizations.localeOf(context).languageCode;
    final webLocale = locale == 'zh' ? 'cn' : locale;
    return AppWebView.open(
      context,
      ProviderScope.containerOf(context),
      AppWebPage(
        path: '/$webLocale/admin/venues/requests/${item.request.id}',
        title: AppLocalizations.of(context).notificationVenueRequestDetail,
        requiresAuth: true,
        embedded: true,
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.minHeight, required this.message});

  final double minHeight;
  final String message;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: minHeight,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          AppIcons.notifications,
          size: 52,
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.35),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(message),
      ],
    ),
  );
}
