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
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'vmito.access_token';
  static const _refreshTokenKey = 'vmito.refresh_token';

  /// Cached so the dio request interceptor stays synchronous — a platform
  /// channel round trip per request would be a real cost on a list screen.
  /// Kept in step with the store by every write path below.
  String? _cachedAccessToken;

  String? get accessToken => _cachedAccessToken;
  bool get hasAccessToken => _cachedAccessToken?.isNotEmpty ?? false;

  /// Must run once at startup, before the first authenticated request.
  Future<void> hydrate() async {
    _cachedAccessToken = await _storage.read(key: _accessTokenKey);
  }

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  /// Refresh responses may omit a new refresh token; keep the existing one.
  Future<void> updateAccessToken(
    String accessToken, [
    String? refreshToken,
  ]) async {
    _cachedAccessToken = accessToken;
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    _cachedAccessToken = null;
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());
