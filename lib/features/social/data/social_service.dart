import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';

class SocialService {
  const SocialService(this._client);

  final ApiClient _client;

  Future<SocialPostPage> feed({required int page, int limit = 10}) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.postsFeed,
      queryParameters: {'page': page, 'limit': limit},
    );
    return SocialPostPage.fromJson(_mapPayload(response.data));
  }

  Future<SocialPost> postById(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.post(id),
    );
    return SocialPost.fromJson(_mapPayload(response.data));
  }

  Future<SocialPost> createPost(
    String content, {
    List<String> imagePaths = const [],
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.posts,
      data: {'content': content},
      options: apiOptions(skipGlobalError: true),
    );
    final post = SocialPost.fromJson(_mapPayload(response.data));
    if (imagePaths.isEmpty) return post;

    final files = <MultipartFile>[];
    for (var index = 0; index < imagePaths.length; index++) {
      final bytes = await FlutterImageCompress.compressWithFile(
        imagePaths[index],
        quality: 82,
      );
      if (bytes != null) {
        files.add(
          MultipartFile.fromBytes(bytes, filename: 'post-$index.jpg'),
        );
      }
    }
    if (files.isNotEmpty) {
      await _client.post<Map<String, dynamic>>(
        '${ApiEndpoints.post(post.id)}/images',
        data: FormData.fromMap({'images': files}),
        options: apiOptions(skipGlobalError: true),
      );
    }
    return postById(post.id);
  }

  Future<({bool liked, int count})> toggleLike(String postId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.postLike(postId),
      options: apiOptions(skipGlobalError: true),
    );
    final payload = _mapPayload(response.data);
    return (
      liked: payload['liked'] as bool? ?? false,
      count: (payload['likeCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<List<SocialComment>> comments(String postId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.postComments(postId),
      queryParameters: const {'page': 1, 'limit': 100},
    );
    final payload = _payload(response.data);
    final raw = payload is Map<String, dynamic>
        ? payload['comments'] as List<dynamic>? ?? const []
        : payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SocialComment.fromJson)
        .toList(growable: false);
  }

  Future<SocialComment> createComment(String postId, String content) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.postComments(postId),
      data: {'content': content},
      options: apiOptions(skipGlobalError: true),
    );
    return SocialComment.fromJson(_mapPayload(response.data));
  }

  Future<SocialPost> repost(String postId) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.postShare(postId),
      options: apiOptions(skipGlobalError: true),
    );
    return SocialPost.fromJson(_mapPayload(response.data));
  }

  Future<ClubPage> browseClubs({
    required int page,
    int limit = 20,
    String? search,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.clubs,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      },
    );
    return ClubPage.fromJson(_payload(response.data));
  }

  Future<ClubSummary> clubById(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.clubDetails(id),
    );
    return ClubSummary.fromJson(_mapPayload(response.data));
  }

  Future<String> joinClub(String id, {String? message}) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.clubJoin(id),
      data: {
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
    return _mapPayload(response.data)['status'] as String? ?? 'pending';
  }

  Future<List<ClubSummary>> managedClubs() async {
    final response = await _client.get<dynamic>(ApiEndpoints.managedClubs);
    final payload = _payload(response.data);
    final raw = payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubSummary.fromJson)
        .toList(growable: false);
  }

  Future<ClubSummary> managedClub(String clubId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.managedClub(clubId),
    );
    return ClubSummary.fromJson(_mapPayload(response.data));
  }

  Future<ClubSummary> createClub(ClubDraft draft) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.clubs,
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return ClubSummary.fromJson(_mapPayload(response.data));
  }

  Future<ClubSummary> updateClub(String clubId, ClubDraft draft) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.managedClub(clubId),
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return ClubSummary.fromJson(_mapPayload(response.data));
  }

  Future<void> deleteClub(String clubId) => _client.delete<void>(
    ApiEndpoints.managedClub(clubId),
    options: apiOptions(skipGlobalError: true),
  );

  Future<List<ClubMember>> clubMembers(String clubId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubMembers(clubId),
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubMember.fromJson)
        .toList(growable: false);
  }

  Future<List<ClubUserSearchResult>> searchClubUsers(
    String clubId,
    String query,
  ) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubUserSearch,
      queryParameters: {'q': query.trim(), 'clubId': clubId},
      dedup: false,
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubUserSearchResult.fromJson)
        .toList(growable: false);
  }

  Future<void> addClubMember(String clubId, String userId) =>
      _client.post<void>(
        ApiEndpoints.clubMember(clubId, userId),
        options: apiOptions(skipGlobalError: true),
      );

  Future<void> removeClubMember(String clubId, String userId) =>
      _client.delete<void>(
        ApiEndpoints.clubMember(clubId, userId),
        options: apiOptions(skipGlobalError: true),
      );

  Future<void> updateClubMemberRole(
    String clubId,
    String userId,
    String role,
  ) => _client.put<void>(
    ApiEndpoints.clubMemberRole(clubId, userId),
    data: {'role': role},
    options: apiOptions(skipGlobalError: true),
  );

  Future<List<ClubJoinRequest>> clubJoinRequests(String clubId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubJoinRequests(clubId),
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubJoinRequest.fromJson)
        .toList(growable: false);
  }

  Future<void> approveClubJoinRequest(String clubId, String requestId) =>
      _client.post<void>(
        ApiEndpoints.clubJoinRequestApprove(clubId, requestId),
        options: apiOptions(skipGlobalError: true),
      );

  Future<void> rejectClubJoinRequest(
    String clubId,
    String requestId, {
    String? response,
  }) => _client.post<void>(
    ApiEndpoints.clubJoinRequestReject(clubId, requestId),
    data: {
      if (response != null && response.trim().isNotEmpty)
        'response': response.trim(),
    },
    options: apiOptions(skipGlobalError: true),
  );

  Future<List<ClubAnnouncement>> clubAnnouncements(String clubId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubAnnouncements(clubId),
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubAnnouncement.fromJson)
        .toList(growable: false);
  }

  Future<ClubAnnouncement> saveClubAnnouncement(
    String clubId, {
    String? announcementId,
    required String title,
    required String content,
    DateTime? pinnedUntil,
  }) async {
    final data = {
      'title': title.trim(),
      'content': content.trim(),
      'pinnedUntil': pinnedUntil?.toUtc().toIso8601String(),
    };
    final response = announcementId == null
        ? await _client.post<Map<String, dynamic>>(
            ApiEndpoints.clubAnnouncements(clubId),
            data: data,
            options: apiOptions(skipGlobalError: true),
          )
        : await _client.put<Map<String, dynamic>>(
            ApiEndpoints.clubAnnouncement(clubId, announcementId),
            data: data,
            options: apiOptions(skipGlobalError: true),
          );
    return ClubAnnouncement.fromJson(_mapPayload(response.data));
  }

  Future<void> deleteClubAnnouncement(
    String clubId,
    String announcementId,
  ) => _client.delete<void>(
    ApiEndpoints.clubAnnouncement(clubId, announcementId),
    options: apiOptions(skipGlobalError: true),
  );

  Future<PublicProfile> publicProfile(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.publicUser(userId),
    );
    return PublicProfile.fromJson(_mapPayload(response.data));
  }

  Future<RatingStats> ratingStats(String userId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.userRatingStats(userId),
    );
    return RatingStats.fromJson(_mapPayload(response.data));
  }

  Future<List<PlayerRating>> receivedRatings(String userId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userReceivedRatings(userId),
    );
    final payload = _payload(response.data);
    final raw = payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PlayerRating.fromJson)
        .toList(growable: false);
  }

  Future<RatingEligibility> ratingEligibility(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionRatingEligibility(sessionId),
    );
    return RatingEligibility.fromJson(_mapPayload(response.data));
  }

  Future<void> createRating({
    required String sessionId,
    required String ratedUserId,
    required String type,
    required int rating,
    String? comment,
  }) async {
    await _client.post<void>(
      ApiEndpoints.ratings,
      data: {
        'sessionId': sessionId,
        'ratedUserId': ratedUserId,
        'type': type,
        'rating': rating,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
      options: apiOptions(skipGlobalError: true),
    );
  }

  dynamic _payload(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('success')) {
      return body['data'];
    }
    return body;
  }

  Map<String, dynamic> _mapPayload(dynamic body) =>
      _payload(body) as Map<String, dynamic>;
}

final socialServiceProvider = Provider<SocialService>(
  (ref) => SocialService(ref.watch(apiClientProvider)),
);
