import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Feed icon with a narrowly subscribed unread-count badge.
///
/// Announces only the count. The enclosing [NavigationDestination] already
/// contributes the tab name, so repeating it here reads it twice.
class NewsfeedBadgeIcon extends ConsumerWidget {
  const NewsfeedBadgeIcon({
    required this.icon,
    super.key,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      newsfeedBadgeControllerProvider.select((state) => state.count),
    );
    if (count == 0) return Icon(icon);

    final badgeLabel = count > 99 ? '99+' : '$count';

    return Semantics(
      label: AppLocalizations.of(context).newsfeedUnreadCount(count),
      excludeSemantics: true,
      child: Badge(
        key: const Key('newsfeed-unread-badge'),
        label: Text(badgeLabel),
        offset: const Offset(6, -4),
        child: Icon(icon),
      ),
    );
  }
}
