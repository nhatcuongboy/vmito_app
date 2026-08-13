import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/presentation/widgets/notification_list_item.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(notificationControllerProvider.notifier).load());
    });
  }

  void _onScroll() {
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const BackButtonIcon(),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go(AppRoutes.home);
          },
        ),
        title: Text(l10n.notificationsTitle),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => unawaited(controller.markAllRead()),
              child: Text(l10n.notificationsMarkAllRead),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: switch (state) {
          _ when state.isLoading && state.items.isEmpty => const Center(
            child: CircularProgressIndicator(),
          ),
          _ when state.error != null && state.items.isEmpty => AppErrorView(
            error: state.error!,
            onRetry: controller.load,
          ),
          _ when state.items.isEmpty => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * .28),
              const Icon(AppIcons.notifications, size: 52),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.notificationsEmpty, textAlign: TextAlign.center),
            ],
          ),
          _ => ListView.separated(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              if (index == state.items.length) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final notification = state.items[index];
              return NotificationListItem(
                notification: notification,
                onTap: () async {
                  await controller.markRead(notification);
                  if (!context.mounted) return;
                  final sessionId = notification.sessionId;
                  if (sessionId != null) {
                    await context.push(AppRoutes.sessionDetail(sessionId));
                  }
                },
                onMarkAsRead: notification.isRead
                    ? null
                    : () => unawaited(controller.markRead(notification)),
                onDelete: () => unawaited(controller.delete(notification.id)),
              );
            },
          ),
        },
      ),
    );
  }
}
