import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class ProfileTabsService {
  const ProfileTabsService(this._client);
  final ApiClient _client;
  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;
  Future<SocialPostPage> posts(String id, {int page = 1}) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userPosts(id),
      queryParameters: {'page': page, 'limit': 10},
    );
    return SocialPostPage.fromJson(
      _payload(response.data) as Map<String, dynamic>,
    );
  }

  Future<UserAchievements> achievements(String id) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userAchievements(id),
    );
    return UserAchievements.fromJson(
      _payload(response.data) as Map<String, dynamic>,
    );
  }

  Future<Page<Session>> hosted(
    String id, {
    int page = 1,
    String filter = 'active',
  }) async {
    final excluded = switch (filter) {
      'active' => 'FINISHED,CANCELLED',
      'ended' => 'PREPARING,IN_PROGRESS',
      _ => null,
    };
    final response = await _client.get<dynamic>(
      ApiEndpoints.publicSessions,
      queryParameters: {
        'hostId': id,
        'page': page,
        'limit': 10,
        'sortBy': 'startTime',
        'sortOrder': 'desc',
        'excludeStatuses': ?excluded,
      },
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  Future<List<ClubSummary>> clubs(String id) async {
    final response = await _client.get<dynamic>(ApiEndpoints.userClubs(id));
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubSummary.fromJson)
        .toList(growable: false);
  }

  Future<Page<FavoriteTarget>> favorites(String type, {int page = 1}) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.favorites,
      queryParameters: {'type': type, 'page': page, 'limit': 10},
    );
    return unwrapPage(response.data, FavoriteTarget.fromJson);
  }
}

final profileTabsServiceProvider = Provider<ProfileTabsService>(
  (ref) => ProfileTabsService(ref.watch(apiClientProvider)),
);
