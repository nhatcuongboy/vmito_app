import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';

/// Keeps the chat session (consent + Stream connection) aligned with the
/// active account, mirroring `SocketIdentityLifecycle` for Socket.IO.
///
/// Only *fetches* `/chat/session` and connects when eligible; sign-out
/// cleanup (disconnect + wipe local cache) runs through
/// `sessionCleanupProvider` in `bootstrap.dart`, the same hook push
/// unregistration uses, so both fire before tokens are cleared.
class ChatLifecycle extends ConsumerStatefulWidget {
  const ChatLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ChatLifecycle> createState() => _ChatLifecycleState();
}

class _ChatLifecycleState extends ConsumerState<ChatLifecycle> {
  ProviderSubscription<AuthState>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AuthState>(
      authControllerProvider,
      (_, auth) => _apply(auth),
      fireImmediately: true,
    );
  }

  void _apply(AuthState auth) {
    if (auth.status != AuthStatus.authenticated) return;
    // Best-effort: chat unavailability must never block the rest of the app.
    unawaited(ref.read(chatSessionControllerProvider.notifier).fetch());
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
