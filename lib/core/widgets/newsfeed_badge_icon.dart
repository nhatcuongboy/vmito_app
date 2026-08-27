import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';

/// Feed icon with a narrowly subscribed unread-count badge.
class NewsfeedBadgeIcon extends ConsumerWidget {
  const NewsfeedBadgeIcon({
    required this.icon,
    required this.semanticLabel,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(
      newsfeedBadgeControllerProvider.select((state) => state.count),
    );
    final badgeLabel = count > 99 ? '99+' : '$count';

    return Semantics(
      label: count > 0 ? '$semanticLabel: $badgeLabel' : semanticLabel,
      excludeSemantics: true,
      child: Badge(
        key: const Key('newsfeed-unread-badge'),
        isLabelVisible: count > 0,
        label: Text(badgeLabel),
        offset: const Offset(6, -4),
        child: Icon(icon),
      ),
    );
  }
}
