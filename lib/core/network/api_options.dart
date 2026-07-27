import 'package:dio/dio.dart';
import 'package:vmito_app/core/network/auth_interceptor.dart'
    show AuthInterceptor;

/// Per-request flags, carried in `RequestOptions.extra`.
///
/// Dart has no equivalent of the axios module augmentation the web app uses
/// (`skipGlobalError`, `_retry` in `base.ts`), so the same two flags live in
/// `extra` behind typed accessors.
abstract final class ApiOptionKeys {
  static const skipGlobalError = 'vmito.skipGlobalError';
  static const isRetry = 'vmito.isRetry';
  static const dedup = 'vmito.dedup';
}

extension ApiRequestOptions on RequestOptions {
  /// Suppress the app-wide error surface for this request; the caller reports
  /// the failure itself. Use on validation-style endpoints (forgot-password,
  /// reset-password, code checks).
  bool get skipGlobalError => extra[ApiOptionKeys.skipGlobalError] == true;
  set skipGlobalError(bool value) =>
      extra[ApiOptionKeys.skipGlobalError] = value;

  /// Set by [AuthInterceptor] before replaying a request post-refresh, so a
  /// second 401 falls through instead of refreshing again.
  bool get isRetry => extra[ApiOptionKeys.isRetry] == true;
  set isRetry(bool value) => extra[ApiOptionKeys.isRetry] = value;
}

/// Builds the [Options] to pass to a dio call.
///
/// ```dart
/// await dio.post('/auth/forgot-password', data: body,
///     options: apiOptions(skipGlobalError: true));
/// ```
Options apiOptions({
  bool skipGlobalError = false,
  Map<String, dynamic>? extra,
}) {
  return Options(
    extra: {
      if (skipGlobalError) ApiOptionKeys.skipGlobalError: true,
      ...?extra,
    },
  );
}
