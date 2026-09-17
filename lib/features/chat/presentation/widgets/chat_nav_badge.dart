import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Chat icon with a badge for unread messages + pending incoming requests.
///
/// Mirrors `NewsfeedBadgeIcon`'s badge styling. `pendingRequestCount` comes
/// straight off the last `/chat/session` fetch (cheaper than loading the
/// full requests list just to count them); unread message count comes from
/// the connected `StreamChatClient`'s own stream, so it updates live without
/// any extra polling.
class ChatNavBadge extends ConsumerWidget {
  const ChatNavBadge({required this.icon, this.color, super.key});

  final IconData icon;

  /// Overrides the icon color — for placements (e.g. a scroll-tinted
  /// header action) that don't want the ambient `IconTheme` color.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(
      chatSessionControllerProvider.select((state) => state.session),
    );
    final client = ref.watch(chatClientProvider);
    final pendingRequests = session?.pendingRequestCount ?? 0;

    if (client == null) {
      return pendingRequests == 0
          ? Icon(icon, color: color)
          : _badge(context, icon, pendingRequests);
    }

    return StreamBuilder<int>(
      stream: client.state.totalUnreadCountStream,
      initialData: client.state.totalUnreadCount,
      builder: (context, snapshot) {
        final count = (snapshot.data ?? 0) + pendingRequests;
        return count == 0
            ? Icon(icon, color: color)
            : _badge(context, icon, count);
      },
    );
  }

  Widget _badge(BuildContext context, IconData icon, int count) {
    final label = count > 99 ? '99+' : '$count';
    return Semantics(
      label: AppLocalizations.of(context).chatUnreadCount(count),
      excludeSemantics: true,
      child: Badge(
        key: const Key('chat-unread-badge'),
        label: Text(label),
        offset: const Offset(6, -4),
        child: Icon(icon, color: color),
      ),
    );
  }
}
