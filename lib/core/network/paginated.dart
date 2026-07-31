import 'package:vmito_app/core/network/api_response.dart';

/// A page of results.
///
/// The backend nests this **inside** the `{success, data}` envelope, so a list
/// endpoint returns `{success, data: {data: [...], total, page, limit,
/// totalPages}}` — two levels of `data`. [unwrapPage] handles both.
class Page<T> {
  const Page({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;

  /// The page to request next, or null when this is the last one.
  int? get nextPage => hasMore ? page + 1 : null;
}

/// Reads a paginated body, tolerating a bare list.
///
/// Some endpoints return `{data, total, ...}`; others return a plain array.
/// Rather than track which is which per endpoint, accept both — the same
/// tolerance principle as [unwrap].
Page<T> unwrapPage<T>(
  dynamic body,
  T Function(Map<String, dynamic>) fromJson,
) {
  final payload = body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;

  if (payload is List) {
    final items = payload
        .cast<Map<String, dynamic>>()
        .map(fromJson)
        .toList(growable: false);
    return Page<T>(
      items: items,
      total: items.length,
      page: 1,
      limit: items.length,
      totalPages: 1,
    );
  }

  if (payload is! Map<String, dynamic>) {
    throw FormatException(
      'Expected a page or list, got ${payload.runtimeType}',
    );
  }

  final rawItems = (payload['data'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>();

  return Page<T>(
    items: rawItems.map(fromJson).toList(growable: false),
    total: _int(payload['total']) ?? rawItems.length,
    page: _int(payload['page']) ?? 1,
    limit: _int(payload['limit']) ?? rawItems.length,
    totalPages: _int(payload['totalPages']) ?? 1,
  );
}

/// Every numeric field arrives as a `num`; take the int explicitly rather than
/// casting, so a `4.0` from JSON does not throw.
int? _int(dynamic value) => (value as num?)?.toInt();
