import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_content.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class NotificationListItem extends StatelessWidget {
  const NotificationListItem({
    required this.notification,
    required this.onTap,
    this.onMarkAsRead,
    required this.onDelete,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isDark = theme.brightness == Brightness.dark;

    // Get localized notification content
    final content = getNotificationDisplayText(notification, l10n);

    return Slidable(
      key: ValueKey(notification.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: onMarkAsRead != null ? 0.35 : 0.25,
        children: [
          if (onMarkAsRead != null)
            SlidableAction(
              onPressed: (_) => onMarkAsRead!(),
              backgroundColor: isDark
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.success,
              foregroundColor: Colors.white,
              icon: AppIcons.check,
              padding: EdgeInsets.zero,
            ),
          SlidableAction(
            onPressed: (_) => onDelete(),
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
        color: notification.isRead
            ? Colors.transparent
            : (isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primary.withValues(alpha: 0.08)),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              // Left accent bar for unread notifications
              if (!notification.isRead)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.brandDark : AppColors.brand,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(2),
                        bottomRight: Radius.circular(2),
                      ),
                    ),
                  ),
                ),
              // Main content
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon with circular background
                    Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(
                        top: 2,
                        right: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: notification.isRead
                            ? (isDark
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.1))
                            : (isDark
                                  ? AppColors.primaryDark.withValues(alpha: 0.3)
                                  : Colors.white),
                        border: Border.all(
                          color: notification.isRead
                              ? (isDark
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.primary.withValues(alpha: 0.2))
                              : (isDark
                                    ? AppColors.primaryDark.withValues(
                                        alpha: 0.5,
                                      )
                                    : AppColors.primary.withValues(alpha: 0.2)),
                        ),
                        boxShadow: notification.isRead
                            ? null
                            : [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Icon(
                        _getIcon(notification.type),
                        size: 17,
                        color: notification.isRead
                            ? (isDark
                                  ? AppColors.primary.withValues(alpha: 0.7)
                                  : AppColors.primary)
                            : (isDark
                                  ? AppColors.primaryDark
                                  : AppColors.primary),
                      ),
                    ),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title
                          Text(
                            content.displayTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: notification.isRead
                                  ? (isDark
                                        ? theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.8))
                                  : (isDark
                                        ? theme.colorScheme.onSurface
                                        : AppColors.primary.withValues(
                                            alpha: 0.95,
                                          )),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Message
                          Text(
                            content.displayMessage,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: notification.isRead
                                  ? (isDark
                                        ? theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.6))
                                  : (isDark
                                        ? theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7)),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          // Time
                          Text(
                            Dates.dayAndTime(
                              notification.createdAt,
                              locale: locale,
                            ),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: notification.isRead
                                  ? (isDark
                                        ? theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4)
                                        : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.5))
                                  : (isDark
                                        ? AppColors.primaryDark.withValues(
                                            alpha: 0.8,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.7,
                                          )),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Unread indicator dot
                    if (!notification.isRead)
                      Container(
                        margin: const EdgeInsets.only(
                          top: 10,
                          left: AppSpacing.xs,
                        ),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.brandDark : AppColors.brand,
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

  IconData _getIcon(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.session:
      case AppNotificationType.registration:
        return AppIcons.sessions;
      case AppNotificationType.payment:
        return AppIcons.creditCard;
      case AppNotificationType.club:
        return AppIcons.clubs;
      case AppNotificationType.tournament:
        return AppIcons.trophy;
      case AppNotificationType.post:
        return AppIcons.feed;
      case AppNotificationType.venueRental:
      case AppNotificationType.venueRequest:
        return AppIcons.court;
      case AppNotificationType.system:
      case AppNotificationType.unknown:
        return AppIcons.notifications;
    }
  }
}
