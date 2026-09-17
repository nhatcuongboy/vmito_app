import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Stream channel id currently open on screen, or null.
///
/// Set by `ChatChannelScreen` on mount/unmount. `PushNotificationLifecycle`
/// reads this to skip showing a local notification banner for a message
/// that just arrived in the conversation the user is already looking at.
class ActiveChatChannelController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? channelId) => state = channelId;
}

final activeChatChannelIdProvider =
    NotifierProvider<ActiveChatChannelController, String?>(
      ActiveChatChannelController.new,
    );
