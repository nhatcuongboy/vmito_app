import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain/Keystore-backed token store.
///
/// The web app keeps tokens in `localStorage` under `auth-storage` (Zustand
/// `persist`). On mobile that is not acceptable — tokens live here and
/// **never** in `shared_preferences`.
class TokenStorage {
  TokenStorage([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              // Token writes must survive an app process being killed during
              // the plugin's cipher migration. The backup is local to the
              // app's secure preferences and is removed after migration.
              migrateWithBackup: true,
            ),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'vmito.access_token';
  static const _refreshTokenKey = 'vmito.refresh_token';
  static const _biometricRefreshTokenKey = 'vmito.biometric_refresh_token';

  /// Cached so the dio request interceptor stays synchronous — a platform
  /// channel round trip per request would be a real cost on a list screen.
  /// Kept in step with the store by every write path below.
  String? _cachedAccessToken;
  String? _cachedRefreshToken;

  String? get accessToken => _cachedAccessToken;

  /// The `sub` claim of the stored access token.
  ///
  /// vmito-be has no `GET /users/me`: that path falls through to
  /// `GET /users/:id` with id `"me"` and answers 403, so restoring a session
  /// must address the user by id. The token is not verified here — the server
  /// verifies it on the request this id is used for.
  String? get userId => _subjectOf(_cachedAccessToken);

  bool get hasAccessToken => _cachedAccessToken?.isNotEmpty ?? false;
  bool get hasRefreshToken => _cachedRefreshToken?.isNotEmpty ?? false;
  bool get hasPersistedSession => hasAccessToken || hasRefreshToken;

  /// Must run once at startup, before the first authenticated request.
  Future<void> hydrate() async {
    final tokens = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
    ]);
    _cachedAccessToken = tokens[0];
    _cachedRefreshToken = tokens[1];
  }

  Future<String?> readRefreshToken() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    _cachedRefreshToken = refreshToken;
    return refreshToken;
  }

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    // Persist the recovery credential first. If the OS kills the process
    // between these two native writes, startup can still mint a new access
    // token from the refresh token instead of losing the session.
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      // A live pair supersedes anything parked for biometrics; the parked one
      // is revoked the moment this pair was minted from it.
      _storage.delete(key: _biometricRefreshTokenKey),
    ]);
    _cachedAccessToken = accessToken;
    _cachedRefreshToken = refreshToken;
  }

  /// Refresh responses may omit a new refresh token; keep the existing one.
  Future<void> updateAccessToken(
    String accessToken, [
    String? refreshToken,
  ]) async {
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      _cachedRefreshToken = refreshToken;
    }
    await _storage.write(key: _accessTokenKey, value: accessToken);
    _cachedAccessToken = accessToken;
  }

  /// Ends the session and parks the refresh token where the auth interceptor
  /// cannot see it.
  ///
  /// Leaving it under [_refreshTokenKey] would let any 401 on a public screen
  /// silently re-authenticate the network layer behind a signed-out UI — the
  /// app would then send a bearer token on requests it believes are anonymous,
  /// and role-gated endpoints answer 403.
  Future<void> parkRefreshTokenForBiometrics() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      if (refreshToken != null)
        _storage.write(key: _biometricRefreshTokenKey, value: refreshToken),
    ]);
  }

  /// Only the biometric sign-in flow may read this.
  Future<String?> readBiometricRefreshToken() =>
      _storage.read(key: _biometricRefreshTokenKey);

  Future<void> clear() async {
    _cachedAccessToken = null;
    _cachedRefreshToken = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _biometricRefreshTokenKey),
    ]);
  }

  static String? _subjectOf(String? token) {
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return switch (payload) {
        {'sub': final String sub} when sub.isNotEmpty => sub,
        _ => null,
      };
    } on FormatException {
      return null;
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
