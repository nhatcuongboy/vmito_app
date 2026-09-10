import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/network/api_exception.dart'
    show ApiErrorKind, ApiException;
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/data/oauth_service.dart';
import 'package:vmito_app/features/auth/domain/oauth_provider.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

/// What the router and the shell need to know about the session.
///
/// `unknown` exists because tokens are read from the Keychain asynchronously.
/// The router must not bounce a signed-in user to sign-in during that window —
/// this is the mobile equivalent of the web app's `isHydrated` flag.
enum AuthStatus { unknown, authenticated, guest, unauthenticated }

const developmentBypassUserId = 'development-bypass-user';

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.wasExplicitlySignedOut = false,
  });

  final AuthStatus status;
  final User? user;
  final bool wasExplicitlySignedOut;

  bool get isResolved => status != AuthStatus.unknown;

  /// True for guests too — they can see session screens without a JWT.
  bool get isSignedIn =>
      status == AuthStatus.authenticated || status == AuthStatus.guest;

  AuthState copyWith({AuthStatus? status, User? user}) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    wasExplicitlySignedOut: wasExplicitlySignedOut,
  );
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
  OAuthService get _oauthService => ref.read(oauthServiceProvider);
  BiometricLockStorage get _biometricLock =>
      ref.read(biometricLockStorageProvider);

  Future<void> _clearPersistedSession() async {
    await _tokens.clear();
    try {
      await _biometricLock.clear();
    } on Object catch (error) {
      // Token removal is the security boundary for sign-out. A failed cleanup
      // of the non-secret preference must not leave the user authenticated.
      AppLogger.warn('biometric lock preference cleanup failed', error: error);
    }
  }

  /// Applies a fresh JWT pair and, when biometric sign-in is armed, records
  /// whose account the Face ID button on the sign-in screen now belongs to.
  ///
  /// Signing in as somebody else overwrites the record, so the button never
  /// offers to resume the previous account.
  Future<void> _completeSignIn(LoginResponse result) async {
    await _tokens.save(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    state = AuthState(status: AuthStatus.authenticated, user: result.user);
    await rememberBiometricAccount(result.user);
  }

  Future<void> rememberBiometricAccount(User user) async {
    try {
      if (!await _biometricLock.readEnabled()) return;
      await _biometricLock.saveAccount(
        BiometricAccount(
          userId: user.id,
          displayName: user.displayName,
          email: user.email,
        ),
      );
    } on Object catch (error) {
      AppLogger.warn('biometric account record failed', error: error);
    }
  }

  /// Drops the saved session so the sign-in screen stops offering Face ID.
  Future<void> forgetBiometricSignIn() => _clearPersistedSession();

  /// Reads persisted tokens and revalidates them against the backend.
  ///
  /// A stored token may be expired; `/users/me` either succeeds, or the
  /// interceptor refreshes transparently, or we fall back to signed-out.
  Future<void> restoreSession() async {
    if (AppConfig.enableAuthBypass) {
      // This is a UI-only development session. Do not persist invented tokens:
      // protected backend endpoints must still require real authentication.
      state = const AuthState(
        status: AuthStatus.authenticated,
        user: User(
          id: developmentBypassUserId,
          email: 'developer@vmito.local',
          name: 'Development User',
          role: UserRole.admin,
        ),
      );
      return;
    }

    await _tokens.hydrate();

    if (!_tokens.hasPersistedSession) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      // The two secure-storage values are separate native writes. If the OS
      // kills the process between them, a durable refresh token is still
      // enough to reconstruct the session on the next launch.
      if (!_tokens.hasAccessToken) {
        final refreshToken = await _tokens.readRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }
        final refreshed = await _service.refreshTokens(refreshToken);
        await _tokens.save(
          accessToken: refreshed.accessToken,
          refreshToken: refreshed.refreshToken,
        );
      }
      final user = await _service.currentUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on ApiException catch (error) {
      AppLogger.warn('session restore failed', error: error);
      if (error.isUnauthorized) await _clearPersistedSession();
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on Object catch (error) {
      AppLogger.warn('session restore failed', error: error);
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  /// Throws [ApiException] on failure — the form catches and renders it.
  Future<void> signIn({required String email, required String password}) async {
    final result = await _service.login(email: email, password: password);
    await _completeSignIn(result);
  }

  /// Resumes the account remembered by [rememberBiometricAccount].
  ///
  /// The caller runs the device prompt first; this only performs the token
  /// exchange. A rejected refresh token means the saved session is gone for
  /// good, so the offer is withdrawn rather than retried.
  Future<void> signInWithBiometrics() async {
    final refreshToken = await _tokens.readBiometricRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await forgetBiometricSignIn();
      throw const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'No saved session to resume.',
        statusCode: 401,
      );
    }

    try {
      final tokens = await _service.refreshTokens(refreshToken);
      await _tokens.save(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      final user = await _service.currentUser();
      state = AuthState(status: AuthStatus.authenticated, user: user);
      await rememberBiometricAccount(user);
    } on ApiException catch (error) {
      if (error.isUnauthorized) await forgetBiometricSignIn();
      rethrow;
    }
  }

  /// Signs in with a verified Apple identity token.
  ///
  /// [givenName] / [familyName] come from Apple's credential and are only
  /// populated on the very first authorization — pass them straight through.
  Future<void> signInWithApple({
    required String identityToken,
    String? givenName,
    String? familyName,
  }) async {
    final result = await _service.signInWithApple(
      identityToken: identityToken,
      givenName: givenName,
      familyName: familyName,
    );
    await _completeSignIn(result);
  }

  /// Runs the backend-driven Google or Facebook browser flow, then stores the
  /// returned JWT pair through the same single session owner as email login.
  Future<void> signInWithOAuth({
    required OAuthProvider provider,
    required String locale,
  }) async {
    final result = await _oauthService.signIn(
      provider: provider,
      locale: locale,
    );
    await _completeSignIn(result);
  }

  /// Deletes the account, then signs out locally.
  ///
  /// Throws [ApiException] if the backend refuses — the caller must surface
  /// that rather than pretending the account is gone. Local state is only
  /// cleared once the server has confirmed.
  Future<void> deleteAccount() async {
    await _service.deleteAccount();
    await _runSessionCleanup();
    await _clearPersistedSession();
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      wasExplicitlySignedOut: true,
    );
    ref.read(sessionDataCleanupProvider)();
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
    await _runSessionCleanup();
    // Signing out is not the same as forgetting the device. When biometric
    // sign-in is armed the refresh token is parked under a key the request
    // interceptor cannot reach, so only an explicit face/fingerprint scan can
    // spend it.
    if (await _isBiometricSignInArmed()) {
      await _tokens.parkRefreshTokenForBiometrics();
    } else {
      await _clearPersistedSession();
    }
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      wasExplicitlySignedOut: true,
    );
    ref.read(sessionDataCleanupProvider)();
  }

  Future<void> _runSessionCleanup({bool unregisterServer = true}) async {
    try {
      await ref.read(sessionCleanupProvider)(
        unregisterServer: unregisterServer,
      );
    } on Object catch (error) {
      AppLogger.warn('session cleanup failed', error: error);
    }
  }

  Future<bool> _isBiometricSignInArmed() async {
    try {
      if (!await _biometricLock.readEnabled()) return false;
      if (await _biometricLock.readAccount() == null) return false;
      final refreshToken = await _tokens.readRefreshToken();
      return refreshToken != null && refreshToken.isNotEmpty;
    } on Object catch (error) {
      AppLogger.warn('biometric sign-in check failed', error: error);
      return false;
    }
  }

  /// Called by the interceptor when refresh fails for good.
  ///
  /// The refresh token is dead, so the biometric offer must go with it.
  Future<void> handleSessionExpired() async {
    await _runSessionCleanup(unregisterServer: false);
    await _clearPersistedSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
    ref.read(sessionDataCleanupProvider)();
  }

  void setUser(User user) => state = state.copyWith(user: user);
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

typedef SessionCleanup = Future<void> Function({bool unregisterServer});

/// Runs authenticated, best-effort cleanup immediately before local tokens are
/// removed. Bootstrap wires push-device unregistration into this hook.
final sessionCleanupProvider = Provider<SessionCleanup>(
  (ref) => ({unregisterServer = true}) async {},
);

/// Clears in-memory data only after authentication has been removed.
///
/// Keeping this separate from [sessionCleanupProvider] prevents active
/// providers from reloading the old account with a still-valid token during
/// sign-out.
final sessionDataCleanupProvider = Provider<void Function()>((ref) => () {});

/// Convenience selectors — prefer these in widgets so a rebuild is scoped to
/// the field that actually changed.
final currentUserProvider = Provider<User?>(
  (ref) => ref.watch(authControllerProvider).user,
);

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).isSignedIn,
);
