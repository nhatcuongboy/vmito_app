import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';
import 'package:vmito_app/features/chat/presentation/chat_consent_view.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

/// `/chat`. Consent gate first-run, then every active DM (plus the current
/// user's own still-pending outgoing requests — see the filter below).
class ChatInboxScreen extends ConsumerStatefulWidget {
  const ChatInboxScreen({super.key});

  @override
  ConsumerState<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends ConsumerState<ChatInboxScreen> {
  StreamChannelListController? _channelListController;
  String? _channelListUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    if (!ref.read(chatSessionControllerProvider).isResolved) {
      await ref.read(chatSessionControllerProvider.notifier).fetch();
    }
  }

  @override
  void dispose() {
    _channelListController?.dispose();
    super.dispose();
  }

  /// A channel appears here once it is active, or while still pending *if*
  /// the current user sent it — a pending channel the current user only
  /// received has zero Stream permissions until they consent (see
  /// `PENDING_RECIPIENT_ROLE` in `vmito-be/src/chat/stream-chat.service.ts`)
  /// and belongs in [ChatConsentView] instead.
  StreamChannelListController _ensureController(
    StreamChatClient client,
    String userId,
  ) {
    if (_channelListController != null && _channelListUserId == userId) {
      return _channelListController!;
    }
    _channelListController?.dispose();
    _channelListUserId = userId;
    final controller = StreamChannelListController(
      client: client,
      filter: Filter.and([
        Filter.equal('type', 'vmito_dm'),
        Filter.in_('members', [userId]),
        Filter.or([
          Filter.equal('vmito_state', 'active'),
          Filter.equal('vmito_requester_id', userId),
        ]),
      ]),
    );
    _channelListController = controller;
    unawaited(controller.doInitialLoad());
    return controller;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionState = ref.watch(chatSessionControllerProvider);
    final session = sessionState.session;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatInboxTitle),
        actions: [
          if (session?.consented == true)
            IconButton(
              key: const Key('chat-inbox-new'),
              icon: const Icon(AppIcons.userPlus),
              tooltip: l10n.chatNewTitle,
              onPressed: () => unawaited(context.push(AppRoutes.chatNew)),
            ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, sessionState)),
    );
  }

  Widget _buildBody(BuildContext context, ChatSessionState sessionState) {
    final l10n = AppLocalizations.of(context);
    final session = sessionState.session;

    if (!sessionState.isResolved) return const AppLoadingView();
    if (session == null) {
      return AppErrorView(
        error: sessionState.error!,
        onRetry: () =>
            unawaited(ref.read(chatSessionControllerProvider.notifier).fetch()),
      );
    }
    if (!session.enabled) return _ChatUnavailableView(l10n: l10n);
    if (!session.consented) {
      return ChatConsentView(
        termsVersion: session.termsVersion,
        pendingRequestCount: session.pendingRequestCount,
      );
    }

    final client = ref.watch(chatClientProvider);
    final userId = ref.watch(currentUserProvider)?.id;
    if (client == null || userId == null) return const AppLoadingView();

    final controller = _ensureController(client, userId);
    return StreamChat(
      client: client,
      child: StreamChannelListView(
        controller: controller,
        onChannelTap: (channel) {
          final id = channel.id;
          if (id != null) unawaited(context.push(AppRoutes.chatChannel(id)));
        },
        emptyBuilder: (context) => _EmptyMessagesView(l10n: l10n),
      ),
    );
  }
}

class _EmptyMessagesView extends StatelessWidget {
  const _EmptyMessagesView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chat, size: 40, color: palette.mutedForeground),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.chatEmptyMessages,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatUnavailableView extends StatelessWidget {
  const _ChatUnavailableView({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = theme.extension<AppPalette>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.wifiOff, size: 40, color: palette.mutedForeground),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.chatUnavailableTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.chatUnavailableBody,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
