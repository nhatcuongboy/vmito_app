import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/auth_interceptor.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

/// The single HTTP entry point. Feature services take this, never a bare [Dio].
///
/// Ports `vmito-fe/src/lib/api/base.ts`, including in-flight GET
/// de-duplication — with the web version's order-dependent cache-key bug
/// fixed (see [_dedupKey]).
class ApiClient {
  ApiClient({required this._dio, required TokenStorage tokenStorage})
    : _tokens = tokenStorage;

  final Dio _dio;
  final TokenStorage _tokens;

  final Map<String, Future<Response<dynamic>>> _inFlightGets = {};

  Dio get raw => _dio;

  /// GET with in-flight de-duplication.
  ///
  /// Several widgets on one screen routinely request the same read-only
  /// resource at the same moment. Identical concurrent GETs share a single
  /// network request; the entry clears once it settles, so data fetched after
  /// a mutation is always fresh.
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool dedup = true,
  }) async {
    if (!dedup) {
      return _guard(
        () => _dio.get<T>(
          path,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ),
      );
    }

    final key = _dedupKey(path, queryParameters);
    final existing = _inFlightGets[key];
    if (existing != null) return await existing as Response<T>;

    final request =
        _guard(
          () => _dio.get<T>(
            path,
            queryParameters: queryParameters,
            options: options,
            cancelToken: cancelToken,
          ),
          // Must stay a block body. `Map.remove` returns the removed value — this
          // very future — and `whenComplete` awaits any Future its callback
          // returns, so the arrow form `=> _inFlightGets.remove(key)` makes the
          // future wait for itself: every deduplicated GET then hangs forever.
          // Caught against the live backend; covered by api_client_test.dart.
        ).whenComplete(() {
          // The removed value is this future. Dropping it is the whole point.
          // ignore: discarded_futures
          _inFlightGets.remove(key);
        });

    _inFlightGets[key] = request;
    return request;
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _guard(
      () => _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ),
    );
  }

  /// Ensures callers only ever see [ApiException].
  ///
  /// [ErrorInterceptor] has already attached the typed error; unwrap it here so
  /// no `DioException` escapes the network layer.
  Future<Response<T>> _guard<T>(Future<Response<T>> Function() send) async {
    try {
      return await send();
    } on DioException catch (e) {
      final attached = e.error;
      throw attached is ApiException ? attached : ApiException.fromDio(e);
    }
  }

  /// Params are sorted before encoding.
  ///
  /// The web app uses `JSON.stringify(config.params)`, whose output depends on
  /// property insertion order, so `{a,b}` and `{b,a}` miss each other and fire
  /// duplicate requests. Sorting makes the key order-independent.
  String _dedupKey(String path, Map<String, dynamic>? params) {
    final token = _tokens.accessToken ?? '';
    if (params == null || params.isEmpty) return '$token|$path|';

    final sorted = Map.fromEntries(
      params.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return '$token|$path|${jsonEncode(sorted)}';
  }
}

/// Wired up in `bootstrap.dart`, which overrides this with a fully configured
/// instance. The bare read throws so a missing override fails loudly.
final apiClientProvider = Provider<ApiClient>((ref) {
  throw UnimplementedError('apiClientProvider must be overridden in bootstrap');
});

/// Builds the configured client. Called once, from `bootstrap.dart`.
ApiClient buildApiClient({
  required TokenStorage tokenStorage,
  required ApiErrorBus errorBus,
  required Future<void> Function() onSessionExpired,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
      // Let the interceptors classify every status; dio should not throw on
      // its own before ErrorInterceptor has seen the response.
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  // A second, interceptor-free client for the refresh call itself — using the
  // main one would recurse through AuthInterceptor.
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(
      tokenStorage: tokenStorage,
      dio: dio,
      onRefresh: (refreshToken) async {
        final response = await refreshDio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        // Enveloped in practice (global TransformInterceptor), but read
        // defensively so a route that opts out still refreshes.
        final body = response.data;
        if (body == null) return null;
        final payload = body.containsKey('success')
            ? body['data'] as Map<String, dynamic>?
            : body;
        final accessToken = payload?['accessToken'] as String?;
        if (accessToken == null) return null;
        await tokenStorage.updateAccessToken(
          accessToken,
          payload?['refreshToken'] as String?,
        );
        return accessToken;
      },
      onSessionExpired: onSessionExpired,
    ),
    ErrorInterceptor(errorBus),
  ]);

  return ApiClient(dio: dio, tokenStorage: tokenStorage);
}
