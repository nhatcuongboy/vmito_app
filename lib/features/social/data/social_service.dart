import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/features/social/domain/club_user_option.dart';
import 'package:vmito_app/features/social/domain/post_composer_draft.dart';
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

  Future<SocialPost> createPost(PostComposerDraft draft) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.posts,
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return SocialPost.fromJson(_mapPayload(response.data));
  }

  Future<PostImageDraft> uploadPostImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 1920,
      quality: 82,
    );
    final response = await _client.post<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: const {'category': 'OTHER'},
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(compressed, filename: filename),
      }),
      options: apiOptions(skipGlobalError: true),
    );
    final image = PostImageDraft.fromJson(
      (_payload(response.data) as Map).cast<String, dynamic>(),
    );
    if (image.url.isEmpty || image.publicId.isEmpty) {
      throw StateError('Image upload returned no asset identifier');
    }
    return image;
  }

  Future<Page<PostImageDraft>> postImages({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {'category': 'OTHER', 'page': page, 'limit': limit},
      dedup: false,
    );
    return unwrapPage<PostImageDraft>(response.data, PostImageDraft.fromJson);
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
    ClubBrowseFilters filters = const ClubBrowseFilters(),
    String? sortBy,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.clubs,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (filters.city?.trim().isNotEmpty ?? false)
          'city': filters.city!.trim(),
        if (filters.districts.isNotEmpty)
          'district': filters.districts.join(','),
        if (filters.levels.isNotEmpty)
          'levels': (filters.levels.toList()..sort()).join(','),
        if (filters.activeDays.isNotEmpty)
          'activeDays': (filters.activeDays.toList()..sort()).join(','),
        if (filters.activePeriods.isNotEmpty)
          'activePeriods':
              (filters.activePeriods.toList()
                    ..sort((a, b) => a.index.compareTo(b.index)))
                  .map((period) => period.wireValue)
                  .join(','),
        'sortBy': ?sortBy,
        'lat': ?latitude,
        'lng': ?longitude,
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

  Future<void> leaveClub(String id) => _client.delete<void>(
    ApiEndpoints.clubLeave(id),
    options: apiOptions(skipGlobalError: true),
  );

  Future<void> cancelClubJoinRequest(String id) => _client.delete<void>(
    ApiEndpoints.cancelClubJoinRequest(id),
    options: apiOptions(skipGlobalError: true),
  );

  Future<List<ClubSummary>> myClubs() async {
    final response = await _client.get<dynamic>(ApiEndpoints.myClubs);
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<ClubJoinRequest>> myClubRequests() =>
      _clubRequests(ApiEndpoints.myClubRequests);

  Future<List<ClubJoinRequest>> managedClubJoinRequests({
    bool admin = false,
  }) => _clubRequests(
    admin
        ? ApiEndpoints.adminClubJoinRequests
        : ApiEndpoints.managedClubJoinRequests,
  );

  Future<List<ClubSummary>> pendingClubs() async {
    final response = await _client.get<dynamic>(ApiEndpoints.pendingClubs);
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ClubSummary.fromJson({
            ...json,
            'role': json['role'] ?? 'ADMIN',
          }),
        )
        .toList(growable: false);
  }

  Future<List<ClubJoinRequest>> _clubRequests(String path) async {
    final response = await _client.get<dynamic>(path);
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubJoinRequest.fromJson)
        .toList(growable: false);
  }

  Future<List<ClubSummary>> managedClubs() async {
    final response = await _client.get<dynamic>(ApiEndpoints.managedClubs);
    final payload = _payload(response.data);
    final raw = payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (json) => ClubSummary.fromJson({
            ...json,
            'role': json['role'] ?? 'ADMIN',
          }),
        )
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

  Future<List<ClubHostUserOption>> searchHostUsers(String query) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.users,
      queryParameters: {'search': query.trim()},
      dedup: false,
    );
    final payload = _payload(response.data);
    final raw = payload is Map
        ? payload['data'] as List<dynamic>? ?? const []
        : payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubHostUserOption.fromJson)
        .where((user) => user.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<({String url, String publicId})> uploadClubImage({
    required Uint8List bytes,
    required String filename,
    required bool logo,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 82,
    );
    final response = await _client.post<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {'category': logo ? 'CLUB' : 'CLUB_COVER'},
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(compressed, filename: filename),
      }),
      options: apiOptions(skipGlobalError: true),
    );
    final payload = _payload(response.data) as Map<String, dynamic>;
    final url = (payload['url'] ?? payload['secureUrl'] ?? '') as String;
    final publicId =
        (payload['publicId'] ?? payload['cloudinaryPublicId'] ?? '') as String;
    if (url.isEmpty || publicId.isEmpty) {
      throw StateError('Image upload returned no asset identifier');
    }
    return (url: url, publicId: publicId);
  }

  Future<List<ClubImageAsset>> myImages({
    String? category,
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {
        'page': page,
        'limit': limit,
        'category': ?category,
      },
      dedup: false,
    );
    final payload = _payload(response.data);
    final raw = payload is Map
        ? payload['data'] as List<dynamic>? ?? const []
        : payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubImageAsset.fromJson)
        .where((image) => image.url.isNotEmpty && image.publicId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> deleteClub(String clubId) => _client.delete<void>(
    ApiEndpoints.managedClub(clubId),
    options: apiOptions(skipGlobalError: true),
  );

  Future<void> approveClub(String clubId) => _client.post<void>(
    ApiEndpoints.approveClub(clubId),
    options: apiOptions(skipGlobalError: true),
  );

  Future<void> rejectClub(String clubId, String reason) => _client.post<void>(
    ApiEndpoints.rejectClub(clubId),
    data: {'reason': reason.trim()},
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

  Future<ClubFeeConfig?> clubFeeForMonth(
    String clubId,
    int year,
    int month,
  ) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubFeeForMonth(clubId, year, month),
    );
    final payload = _payload(response.data);
    return payload is Map<String, dynamic>
        ? ClubFeeConfig.fromJson(payload)
        : null;
  }

  Future<List<ClubMonthlyMember>> clubMonthlyMembers(
    String clubId,
    int year,
    int month,
  ) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.clubMonthlyMembers(clubId, year, month),
    );
    final raw = _payload(response.data) as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ClubMonthlyMember.fromJson)
        .toList(growable: false);
  }

  Future<ClubFeeConfig> saveClubFee(
    String clubId, {
    required int year,
    required int month,
    int? maleFeeMonthly,
    int? femaleFeeMonthly,
    int? maleFeePerSession,
    int? femaleFeePerSession,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.clubFees(clubId),
      data: {
        'year': year,
        'month': month,
        'maleFeeMonthly': maleFeeMonthly,
        'femaleFeeMonthly': femaleFeeMonthly,
        'maleFeePerSession': maleFeePerSession,
        'femaleFeePerSession': femaleFeePerSession,
      },
      options: apiOptions(skipGlobalError: true),
    );
    return ClubFeeConfig.fromJson(_mapPayload(response.data));
  }

  Future<ClubMonthlyMember> addClubMonthlyMember(
    String clubId, {
    required String userId,
    required int year,
    required int month,
  }) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.clubMonthlyMember(clubId),
      data: {'userId': userId, 'year': year, 'month': month},
      options: apiOptions(skipGlobalError: true),
    );
    return ClubMonthlyMember.fromJson(_mapPayload(response.data));
  }

  Future<void> removeClubMonthlyMember(
    String clubId, {
    required String userId,
    required int year,
    required int month,
  }) => _client.delete<void>(
    ApiEndpoints.deleteClubMonthlyMember(clubId, userId, year, month),
    options: apiOptions(skipGlobalError: true),
  );

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

  Future<List<RatingStats>> batchRatingStats(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final response = await _client.post<dynamic>(
      ApiEndpoints.userRatingBatchStats,
      data: {'userIds': userIds},
    );
    final payload = _payload(response.data);
    final raw = payload as List<dynamic>? ?? const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(RatingStats.fromJson)
        .toList(growable: false);
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
