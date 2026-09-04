import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_content.dart';
import 'package:vmito_app/features/social/presentation/widgets/post_avatar.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    this.onMarkAsRead,
    this.deleting = false,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback onDelete;
  final bool deleting;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = !notification.isRead;
    final content = getNotificationDisplayText(notification, l10n);
    final accent = isDark ? AppColors.brandDark : AppColors.brand;
    final unreadBackground = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.08);

    return Slidable(
      key: ValueKey(notification.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: onMarkAsRead == null ? 0.24 : 0.42,
        children: [
          if (onMarkAsRead case final onMarkAsRead?)
            SlidableAction(
              onPressed: (_) => onMarkAsRead(),
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              icon: AppIcons.check,
              label: l10n.notificationMarkAsRead,
            ),
          SlidableAction(
            key: ValueKey('swipe-delete-notification-${notification.id}'),
            onPressed: deleting ? null : (_) => onDelete(),
            backgroundColor: isDark
                ? AppColors.destructiveDark
                : AppColors.destructive,
            foregroundColor: Colors.white,
            icon: AppIcons.delete,
            label: l10n.notificationDelete,
          ),
        ],
      ),
      child: Material(
        color: isUnread ? unreadBackground : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (isUnread)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(2),
                      ),
                    ),
                    child: const SizedBox(width: 4),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NotificationLeading(
                      notification: notification,
                      unread: isUnread,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  content.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isUnread
                                        ? (isDark
                                              ? theme.colorScheme.onSurface
                                              : AppColors.primary.withValues(
                                                  alpha: 0.95,
                                                ))
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                              if (isUnread) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            content.displayMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: isUnread ? 0.90 : (isDark ? 0.76 : 0.65),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            Dates.timeAgo(
                              notification.createdAt,
                              locale: locale,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isUnread
                                  ? accent
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: isDark ? 0.70 : 0.55,
                                    ),
                              fontWeight: isUnread
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationLeading extends StatelessWidget {
  const _NotificationLeading({
    required this.notification,
    required this.unread,
  });

  final AppNotification notification;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    if (notification.hasRelatedUser) {
      return PostAvatar(
        name: notification.actorName!,
        imageUrl: notification.actorAvatar,
        size: 36,
        bordered: true,
      );
    }
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md),
        color: unread
            ? (isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.25)
                  : Colors.white)
            : AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.08),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: unread ? 0.25 : 0.15),
        ),
        boxShadow: unread
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Icon(
        notificationIcon(notification),
        size: 18,
        color: isDark ? AppColors.primaryDark : AppColors.primary,
      ),
    );
  }
}

IconData notificationIcon(AppNotification notification) {
  if (notification.action?.endsWith('_favorited') ?? false) {
    return AppIcons.favorite;
  }
  return switch (notification.type) {
    AppNotificationType.session => AppIcons.notifications,
    AppNotificationType.registration => AppIcons.mail,
    AppNotificationType.payment => AppIcons.creditCard,
    AppNotificationType.club => AppIcons.clubs,
    AppNotificationType.tournament => AppIcons.favorite,
    AppNotificationType.post =>
      notification.action == 'post_commented'
          ? AppIcons.chat
          : AppIcons.favorite,
    AppNotificationType.venueRental ||
    AppNotificationType.venueRequest => AppIcons.mapPin,
    AppNotificationType.system => AppIcons.shield,
    AppNotificationType.unknown => AppIcons.notifications,
  };
}
