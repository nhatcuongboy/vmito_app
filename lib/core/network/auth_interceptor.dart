import 'dart:async';

import 'package:dio/dio.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

/// Attaches the bearer token and performs single-flight 401 refresh.
///
/// Ports the axios response interceptor in `vmito-fe/src/lib/api/base.ts`:
/// one refresh at a time, with concurrent 401s queued behind it and replayed
/// with the new token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required TokenStorage tokenStorage,
    required this._dio,
    required this._onRefresh,
    required this._onSessionExpired,
  }) : _tokens = tokenStorage;

  final TokenStorage _tokens;
  final Dio _dio;

  /// Performs `POST /auth/refresh` on a **separate** Dio instance without this
  /// interceptor, returning the new access token, or null if refresh failed.
  final Future<String?> Function(String refreshToken) _onRefresh;

  /// Called once when refresh definitively fails: clear auth, route to sign-in.
  final Future<void> Function() _onSessionExpired;

  Future<String?>? _inFlightRefresh;

  /// Auth endpoints must never trigger a refresh — `/auth/refresh` above all,
  /// or a dead refresh token loops forever.
  static const _noRefreshPaths = <String>[
    '/auth/login',
    '/auth/register',
    '/auth/refresh',
    '/auth/forgot-password',
    '/auth/reset-password',
  ];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;

    final shouldRefresh =
        err.response?.statusCode == 401 &&
        !request.isRetry &&
        !_isAuthPath(request.path);

    if (!shouldRefresh) {
      handler.next(err);
      return;
    }

    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      // A guest hitting a protected endpoint. Not a session expiry — don't
      // sign anyone out, just surface the 401.
      handler.next(err);
      return;
    }

    final newToken = await (_inFlightRefresh ??= _refresh(refreshToken));

    if (newToken == null) {
      await _onSessionExpired();
      handler.next(err);
      return;
    }

    try {
      request
        ..isRetry = true
        ..headers['Authorization'] = 'Bearer $newToken';
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<String?> _refresh(String refreshToken) async {
    try {
      return await _onRefresh(refreshToken);
    } on Object catch (_) {
      return null;
    } finally {
      _inFlightRefresh = null;
    }
  }

  bool _isAuthPath(String path) =>
      _noRefreshPaths.any((candidate) => path.contains(candidate));
}
