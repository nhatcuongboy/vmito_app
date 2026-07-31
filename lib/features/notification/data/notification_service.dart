import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';

class NotificationService {
  const NotificationService(this._client);

  final ApiClient _client;

  Future<Page<AppNotification>> list({int page = 1, int limit = 20}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      queryParameters: {'page': page, 'limit': limit},
    );
    final envelope = response.data;
    final payload = envelope?['success'] == true ? envelope!['data'] : envelope;
    if (payload is! Map<String, dynamic>) {
      throw const FormatException('Expected notification page');
    }
    final items = (payload['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
    final pagination =
        payload['pagination'] as Map<String, dynamic>? ?? payload;
    return Page(
      items: items,
      total: (pagination['total'] as num?)?.toInt() ?? items.length,
      page: (pagination['page'] as num?)?.toInt() ?? page,
      limit: (pagination['limit'] as num?)?.toInt() ?? limit,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<int> unreadCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.notificationUnreadCount,
      dedup: false,
    );
    final value = unwrap(response.data, (json) => json);
    return (value['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) =>
      _client.patch<void>(ApiEndpoints.notificationRead(id));

  Future<void> markAllRead() =>
      _client.patch<void>(ApiEndpoints.notificationReadAll);
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(ref.watch(apiClientProvider)),
);
