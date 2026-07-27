import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/network/api_exception.dart' show ApiException;
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

/// What the router and the shell need to know about the session.
///
/// `unknown` exists because tokens are read from the Keychain asynchronously.
/// The router must not bounce a signed-in user to sign-in during that window —
/// this is the mobile equivalent of the web app's `isHydrated` flag.
enum AuthStatus { unknown, authenticated, guest, unauthenticated }

class AuthState {
  const AuthState({this.status = AuthStatus.unknown, this.user});

  final AuthStatus status;
  final User? user;

  bool get isResolved => status != AuthStatus.unknown;

  /// True for guests too — they can see session screens without a JWT.
  bool get isSignedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.guest;

  AuthState copyWith({AuthStatus? status, User? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

/// The single owner of session state.
///
/// Replaces `useAuthStore` from the web app. Nothing else writes tokens:
/// services read them through the interceptor, screens read them from here.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // No async work in build() — the router would rebuild mid-navigation.
    // bootstrap.dart calls restoreSession() once, before runApp.
    return const AuthState();
  }

  TokenStorage get _tokens => ref.read(tokenStorageProvider);
  AuthService get _service => ref.read(authServiceProvider);

  /// Reads persisted tokens and revalidates them against the backend.
  ///
  /// A stored token may be expired; `/users/me` either succeeds, or the
  /// interceptor refreshes transparently, or we fall back to signed-out.
  Future<void> restoreSession() async {
    await _tokens.hydrate();

    if (!_tokens.hasAccessToken) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final user = await _service.currentUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on Object catch (error) {
      AppLogger.warn('session restore failed', error: error);
      await _tokens.clear();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Throws [ApiException] on failure — the form catches and renders it.
  Future<void> signIn({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    await _tokens.save(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
  }

  /// Guests hold no JWT: identity is the player/session pair from a join code.
  void signInAsGuest({
    required String playerId,
    required String sessionId,
    required String joinCode,
  }) {
    state = AuthState(
      status: AuthStatus.guest,
      user: User(
        id: 'guest-$playerId',
        email: '',
        role: UserRole.guest,
        playerId: playerId,
        sessionId: sessionId,
        joinCode: joinCode,
      ),
    );
  }

  Future<void> signOut() async {
    await _tokens.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by the interceptor when refresh fails for good.
  Future<void> handleSessionExpired() async {
    await _tokens.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void setUser(User user) => state = state.copyWith(user: user);
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

/// Convenience selectors — prefer these in widgets so a rebuild is scoped to
/// the field that actually changed.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authControllerProvider).user,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isSignedIn,
);
