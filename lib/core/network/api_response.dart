/// The backend's response envelope: `{ success, data }`.
///
/// Applied to every JSON response by `TransformInterceptor`, a **global**
/// interceptor registered in `vmito-be/src/main.ts`. Verified against the live
/// API — including `/auth/refresh` and `/auth/register`, which
/// FLUTTER_PORT_ASSESSMENT.md claims are bare. They are not.
///
/// [unwrap] still sniffs for the `success` key rather than assuming, so a
/// route that opts out (anything using `@Res()`, such as the OAuth redirects)
/// keeps working without a special case.
class ApiEnvelope<T> {
  const ApiEnvelope({required this.data, this.success = true, this.message});

  final T data;
  final bool success;
  final String? message;
}

/// Unwraps a backend body that may or may not be enveloped.
///
/// ```dart
/// final user = unwrap(response.data, User.fromJson);
/// ```
T unwrap<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
  final json = _payload(body);
  return fromJson(json as Map<String, dynamic>);
}

/// List variant of [unwrap].
List<T> unwrapList<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
  final payload = _payload(body);
  if (payload is! List) {
    throw FormatException(
      'Expected a list payload, got ${payload.runtimeType}',
    );
  }
  return payload
      .cast<Map<String, dynamic>>()
      .map(fromJson)
      .toList(growable: false);
}

dynamic _payload(dynamic body) {
  if (body is Map<String, dynamic> && body.containsKey('success')) {
    return body['data'];
  }
  return body;
}
