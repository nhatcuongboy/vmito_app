import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/realtime/socket_client.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';

/// Keeps the Socket.IO handshake and authenticated user room aligned with the
/// active account for the lifetime of the app.
class SocketIdentityLifecycle extends ConsumerStatefulWidget {
  const SocketIdentityLifecycle({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SocketIdentityLifecycle> createState() =>
      _SocketIdentityLifecycleState();
}

class _SocketIdentityLifecycleState
    extends ConsumerState<SocketIdentityLifecycle> {
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
    final userId = auth.status == AuthStatus.authenticated
        ? auth.user?.id
        : null;
    ref.read(socketClientProvider).setAuthenticatedUser(userId);
  }

  @override
  void dispose() {
    _subscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
