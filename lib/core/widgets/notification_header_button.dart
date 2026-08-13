import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Opens the notification inbox and exposes the current unread count.
class NotificationHeaderButton extends ConsumerStatefulWidget {
  const NotificationHeaderButton({super.key});

  @override
  ConsumerState<NotificationHeaderButton> createState() =>
      _NotificationHeaderButtonState();
}

class _NotificationHeaderButtonState
    extends ConsumerState<NotificationHeaderButton> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(notificationControllerProvider.notifier).refreshUnreadCount(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(
      notificationControllerProvider.select((state) => state.unreadCount),
    );
    final l10n = AppLocalizations.of(context);
    final badgeLabel = unreadCount > 99 ? '99+' : '$unreadCount';

    return Semantics(
      button: true,
      label: unreadCount == 0
          ? l10n.notificationsTitle
          : '${l10n.notificationsTitle}: $badgeLabel',
      child: IconButton(
        tooltip: l10n.notificationsTitle,
        constraints: const BoxConstraints.tightFor(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
        ),
        onPressed: () => context.push(AppRoutes.notifications),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(AppIcons.notifications),
            if (unreadCount > 0)
              Positioned(
                top: -7,
                right: -9,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.xxs,
                      ),
                      child: Text(
                        badgeLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
