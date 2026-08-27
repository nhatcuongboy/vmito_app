import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';

/// Background-only REST access for the newsfeed unread badge.
class NewsfeedBadgeService {
  const NewsfeedBadgeService(this._client);

  final ApiClient _client;

  Future<int> unreadCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.unreadFeedCount,
      options: apiOptions(skipGlobalError: true),
    );
    final payload = unwrap(response.data, (json) => json);
    final count = (payload['count'] as num?)?.toInt() ?? 0;
    return count < 0 ? 0 : count;
  }

  Future<void> markAsRead() => _client.post<void>(
    ApiEndpoints.markFeedAsRead,
    options: apiOptions(skipGlobalError: true),
  );
}

final newsfeedBadgeServiceProvider = Provider<NewsfeedBadgeService>(
  (ref) => NewsfeedBadgeService(ref.watch(apiClientProvider)),
);
