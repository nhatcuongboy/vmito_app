import 'package:dio/dio.dart';

/// A network failure reduced to something a screen can act on.
///
/// Ports `vmito-fe/src/lib/api/apiError.ts`: the raw response body never
/// reaches the UI (Cloudflare's `application/problem+json` in particular), only
/// a short message. Full detail stays on [raw] for the logger.
class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.raw,
  });

  factory ApiException.fromDio(DioException e) {
    final status = e.response?.statusCode;

    final kind = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiErrorKind.timeout,
      DioExceptionType.connectionError => ApiErrorKind.network,
      DioExceptionType.cancel => ApiErrorKind.cancelled,
      _ => _kindForStatus(status),
    };

    return ApiException(
      kind: kind,
      message: _extractMessage(e.response?.data) ?? kind.defaultMessage,
      statusCode: status,
      raw: e.response?.data ?? e.message,
    );
  }

  final ApiErrorKind kind;

  /// Short, user-safe text. Screens may show this directly.
  final String message;
  final int? statusCode;

  /// Unsanitised body — for logs only, never for the UI.
  final Object? raw;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  /// True when a retry could plausibly succeed — drives "Try again" buttons.
  bool get isRetryable =>
      kind == ApiErrorKind.timeout ||
      kind == ApiErrorKind.network ||
      kind == ApiErrorKind.server;

  static ApiErrorKind _kindForStatus(int? status) {
    if (status == null) return ApiErrorKind.unknown;
    if (status == 401) return ApiErrorKind.unauthorized;
    if (status == 403) return ApiErrorKind.forbidden;
    if (status == 404) return ApiErrorKind.notFound;
    if (status == 422 || status == 400) return ApiErrorKind.validation;
    if (status >= 500) return ApiErrorKind.server;
    return ApiErrorKind.unknown;
  }

  /// Digs the user-facing text out of the backend's error body.
  ///
  /// `HttpExceptionFilter` in vmito-be produces a **nested** shape — verified
  /// against the live API:
  ///
  /// ```json
  /// { "success": false,
  ///   "error": { "message": "Invalid credentials",
  ///              "error": "Unauthorized",
  ///              "statusCode": 401 },
  ///   "statusCode": 401 }
  /// ```
  ///
  /// `message` is a string, or a **list** of strings for class-validator
  /// failures. Reading a top-level `message` therefore finds nothing — the
  /// bare shape is only kept as a fallback for anything not routed through
  /// that filter (a proxy, or a plain Nest default).
  static String? _extractMessage(dynamic body) {
    if (body is! Map) return null;

    final nested = body['error'];
    if (nested is Map) {
      final text = _asText(nested['message']) ?? _asText(nested['error']);
      if (text != null) return text;
    }

    return _asText(body['message']) ?? _asText(nested);
  }

  /// Validation failures arrive as a list; join them so the user sees every
  /// problem at once instead of only the first field.
  static String? _asText(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    if (value is List && value.isNotEmpty) {
      return value.map((e) => e.toString()).join('\n');
    }
    return null;
  }

  @override
  String toString() => 'ApiException($kind, $statusCode): $message';
}

enum ApiErrorKind {
  network('Không có kết nối mạng. Vui lòng thử lại.'),
  timeout('Yêu cầu quá thời gian chờ. Vui lòng thử lại.'),
  unauthorized('Phiên đăng nhập đã hết hạn.'),
  forbidden('Bạn không có quyền thực hiện thao tác này.'),
  notFound('Không tìm thấy dữ liệu.'),
  validation('Dữ liệu không hợp lệ.'),
  server('Máy chủ đang gặp sự cố. Vui lòng thử lại sau.'),
  cancelled('Yêu cầu đã bị huỷ.'),
  unknown('Đã có lỗi xảy ra. Vui lòng thử lại.');

  const ApiErrorKind(this.defaultMessage);

  /// Vietnamese fallback used only when the backend sends nothing usable.
  /// Screens should prefer a localised string keyed off [ApiErrorKind].
  final String defaultMessage;
}
