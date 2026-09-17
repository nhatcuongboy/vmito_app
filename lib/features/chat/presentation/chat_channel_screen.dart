import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/chat/application/active_chat_channel.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';
import 'package:vmito_app/features/chat/data/chat_service.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// `/chat/channel/:channelId`. Wraps the SDK's own list/composer widgets;
/// the only custom behaviour is the pending-request banner (see
/// `vmito-be/src/chat/stream-chat.service.ts` — a still-pending channel
/// grants the sender read-only access and the recipient none at all).
class ChatChannelScreen extends ConsumerStatefulWidget {
  const ChatChannelScreen({required this.channelId, this.requestId, super.key});

  final String channelId;

  /// The `ChatConversation` id, only known right after sending the initial
  /// request — see `AppRoutes.chatChannel`. Enables the Cancel action.
  final String? requestId;

  @override
  ConsumerState<ChatChannelScreen> createState() => _ChatChannelScreenState();
}

class _ChatChannelScreenState extends ConsumerState<ChatChannelScreen> {
  Channel? _channel;
  Object? _error;
  var _isLoading = true;
  var _isCancelling = false;

  @override
  void initState() {
    super.initState();
    ref.read(activeChatChannelIdProvider.notifier).set(widget.channelId);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  @override
  void dispose() {
    if (ref.read(activeChatChannelIdProvider) == widget.channelId) {
      ref.read(activeChatChannelIdProvider.notifier).set(null);
    }
    super.dispose();
  }

  Future<void> _load() async {
    final client = ref.read(chatClientProvider);
    if (client == null) {
      setState(() {
        _error = StateError('Chat client not connected');
        _isLoading = false;
      });
      return;
    }
    final channel = client.channel('vmito_dm', id: widget.channelId);
    try {
      await channel.watch();
      if (!mounted) return;
      setState(() {
        _channel = channel;
        _isLoading = false;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final requestId = widget.requestId;
    if (requestId == null || _isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await ref.read(chatServiceProvider).cancelRequest(requestId);
      if (mounted) context.pop();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ApiException
                  ? error.message
                  : AppLocalizations.of(context).chatConsentError,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: AppLoadingView());
    final client = ref.read(chatClientProvider);
    final channel = _channel;
    if (client == null || channel == null) {
      return Scaffold(
        body: AppErrorView(
          error: _error ?? StateError('Channel unavailable'),
          onRetry: () => unawaited(_load()),
        ),
      );
    }

    final currentUserId = ref.watch(currentUserProvider)?.id;
    final isPending = channel.extraData['vmito_state'] == 'pending';
    final isPendingSender =
        isPending && channel.extraData['vmito_requester_id'] == currentUserId;

    return StreamChat(
      client: client,
      child: StreamChannel(
        channel: channel,
        child: Scaffold(
          appBar: const StreamChannelHeader(),
          body: SafeArea(
            child: Column(
              children: [
                if (isPending)
                  _PendingBanner(
                    isSender: isPendingSender,
                    canCancel: widget.requestId != null,
                    isCancelling: _isCancelling,
                    onCancel: () => unawaited(_cancel()),
                  ),
                const Expanded(child: StreamMessageListView()),
                if (!isPending) StreamMessageComposer(disableAttachments: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({
    required this.isSender,
    required this.canCancel,
    required this.isCancelling,
    required this.onCancel,
  });

  final bool isSender;
  final bool canCancel;
  final bool isCancelling;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      color: palette.muted.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSender
                ? l10n.chatPendingBannerSender
                : l10n.chatPendingBannerRecipient,
            style: theme.textTheme.bodyMedium,
          ),
          if (isSender && canCancel) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: isCancelling ? null : onCancel,
                child: isCancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.chatCancelAction),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
