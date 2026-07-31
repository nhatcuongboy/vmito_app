import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
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
              const Icon(Icons.notifications_none_rounded, size: 52),
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
              return _NotificationTile(
                notification: notification,
                onTap: () async {
                  await controller.markRead(notification);
                  if (!context.mounted) return;
                  final sessionId = notification.sessionId;
                  if (sessionId != null) {
                    await context.push(AppRoutes.sessionDetail(sessionId));
                  }
                },
              );
            },
          ),
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Material(
      color: notification.isRead
          ? Colors.transparent
          : Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .3),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_icon(notification.type), size: 20)),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              Dates.dayAndTime(notification.createdAt, locale: locale),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: notification.isRead
            ? null
            : const Icon(Icons.circle, size: 9),
        onTap: onTap,
      ),
    );
  }

  IconData _icon(AppNotificationType type) => switch (type) {
    AppNotificationType.session ||
    AppNotificationType.registration => Icons.sports_tennis_rounded,
    AppNotificationType.payment => Icons.payments_outlined,
    AppNotificationType.club => Icons.groups_outlined,
    AppNotificationType.tournament => Icons.emoji_events_outlined,
    AppNotificationType.post => Icons.article_outlined,
    AppNotificationType.venueRental ||
    AppNotificationType.venueRequest => Icons.stadium_outlined,
    _ => Icons.notifications_outlined,
  };
}
