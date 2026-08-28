import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Opens the unified notification inbox and exposes its total attention count.
class NotificationHeaderButton extends ConsumerStatefulWidget {
  const NotificationHeaderButton({super.key, this.color});

  final Color? color;

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
    final badgeCount = ref.watch(
      notificationControllerProvider.select((state) => state.totalBadgeCount),
    );
    final l10n = AppLocalizations.of(context);
    final badgeLabel = badgeCount > 99 ? '99+' : '$badgeCount';

    return Semantics(
      button: true,
      label: badgeCount == 0
          ? l10n.notificationsTitle
          : '${l10n.notificationsTitle}: $badgeLabel',
      child: IconButton(
        tooltip: l10n.notificationsTitle,
        constraints: const BoxConstraints.tightFor(
          width: AppSizes.minTapTarget,
          height: AppSizes.minTapTarget,
        ),
        onPressed: () => context.push(AppRoutes.notifications),
        icon: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text(badgeLabel),
          offset: const Offset(6, -4),
          child: Icon(AppIcons.notifications, color: widget.color),
        ),
      ),
    );
  }
}
