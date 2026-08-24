import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/bulk_create_session.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';
// Shadows `dart:core`'s `Match` in this file. Intentional — the model mirrors
// the backend entity, and no regex work happens here.
import 'package:vmito_app/shared/models/match.dart';

/// Ports `vmito-fe/src/lib/api/session.service.ts`.
///
/// Only the browse endpoints so far. Add a method when a screen needs it —
/// the web service has far more, and porting it wholesale would be dead code
/// with an untested JSON contract.
class SessionRepositoryImpl implements SessionRepository {
  const SessionRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  /// Public session browse. Requires no token, which is deliberate: App Store
  /// guideline 5.1.1(i) forbids gating browsing behind registration.
  /// [limit] has no default on purpose: a silent default here and an explicit
  /// page size in the controller would drift apart without anyone noticing.
  Future<Page<Session>> browsePublic({
    required int limit,
    int page = 1,
    String? search,
    SessionStatus? status,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.publicSessions,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (status != null) 'status': _statusParam(status),
      },
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  @override
  Future<Page<Session>> browseAvailable({
    required int limit,
    int page = 1,
    String? search,
    DateTime? date,
    required Set<SessionTimeRange> timeRanges,
    required Set<int> levels,
    required Set<SessionSport> sports,
    bool? hasSlots,
    String? sessionType,
    String? city,
    required Set<String> districts,
    int? minFee,
    int? maxFee,
    required bool splitEvenly,
    double? latitude,
    double? longitude,
    required bool sortByDistance,
    String? venueId,
  }) async {
    final queryParameters = {
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty)
        'searchQuery': search.trim(),
      if (date != null)
        'date':
            '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
      if (timeRanges.isNotEmpty)
        'timeRanges': timeRanges.map((value) => value.wireValue).join(','),
      if (levels.isNotEmpty) 'levels': levels.join(','),
      if (sports.isNotEmpty)
        'sportType': sports.map((value) => value.wireValue).join(','),
      'hasSlots': ?hasSlots,
      'city': ?city,
      if (districts.isNotEmpty) 'district': districts.join(','),
      'minFee': ?minFee,
      'maxFee': ?maxFee,
      if (splitEvenly) 'feeType': 'SPLIT_EVENLY',
      if (sortByDistance && latitude != null) 'lat': latitude,
      if (sortByDistance && longitude != null) 'lng': longitude,
      if (sortByDistance && latitude != null && longitude != null)
        'sortByDistance': true,
      if (sessionType != null && sessionType != 'all')
        'sessionType': sessionType,
      if (venueId != null && venueId.trim().isNotEmpty)
        'venueId': venueId.trim(),
    };
    final url =
        Uri.parse(
          '${AppConfig.apiBaseUrl}${ApiEndpoints.availableSessions}',
        ).replace(
          queryParameters: queryParameters.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        );
    AppLogger.network('GET $url');
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.availableSessions,
      queryParameters: queryParameters,
    );
    AppLogger.network('GET $url -> ${response.statusCode}');
    return unwrapPage(response.data, Session.fromJson);
  }

  /// Sessions this user hosts. Requires a token.
  ///
  /// The endpoint takes `hostId` rather than inferring it from the JWT, so an
  /// admin can list another host's sessions with the same call.
  @override
  Future<Page<Session>> hostedBy(
    String hostId, {
    required int limit,
    int page = 1,
    SessionListQuery? query,
  }) async {
    final effective = query ?? SessionListQuery(page: page, limit: limit);
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mySessions,
      queryParameters: _sessionListParameters(effective, hostId: hostId),
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  @override
  Future<int> publicSessionCountByHost(String hostId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.publicSessions,
      queryParameters: {'hostId': hostId, 'page': 1, 'limit': 1},
    );
    return unwrapPage(response.data, Session.fromJson).total;
  }

  @override
  Future<int> openSessionCountByHost(String hostId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.availableSessions,
      queryParameters: {'hostId': hostId, 'page': 1, 'limit': 1},
    );
    // This endpoint alone nests its totals under `pagination`, which
    // `unwrapPage` does not read.
    return unwrap(response.data, (json) {
      final pagination = json['pagination'] as Map<String, dynamic>?;
      return (pagination?['total'] as num?)?.toInt() ?? 0;
    });
  }

  @override
  Future<Page<Session>> joinedByCurrentUser(SessionListQuery query) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.joinedSessions,
      queryParameters: _sessionListParameters(query),
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  @override
  Future<Page<PendingJoinRequest>> pendingJoinRequests({
    required int page,
    required int limit,
    String? search,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.pendingJoinRequests,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty)
          'searchQuery': search.trim(),
      },
    );
    return unwrapPage(response.data, PendingJoinRequest.fromJson);
  }

  @override
  Future<int> pendingJoinRequestCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.pendingJoinRequestCount,
    );
    final body = response.data ?? const <String, dynamic>{};
    final payload = body['success'] == null ? body : body['data'];
    if (payload is Map) return (payload['count'] as num?)?.toInt() ?? 0;
    return 0;
  }

  Map<String, dynamic> _sessionListParameters(
    SessionListQuery query, {
    String? hostId,
  }) => {
    'hostId': ?hostId,
    'page': query.page,
    'limit': query.limit,
    'sortBy': query.sortBy,
    'sortOrder': query.sortOrder,
    if (query.search != null && query.search!.trim().isNotEmpty)
      'searchQuery': query.search!.trim(),
    if (query.status != null) 'status': _statusParam(query.status!),
    if (query.excludedStatuses.isNotEmpty)
      'excludeStatuses': query.excludedStatuses.map(_statusParam).join(','),
  };

  /// Creates a session and returns it as the backend stored it.
  ///
  /// Takes the already-built request rather than a long parameter list: the
  /// backend accepts 30 optional fields, and a positional signature here would
  /// be unreadable and easy to mis-order. See [CreateSessionRequest].
  @override
  Future<Session> create(CreateSessionRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.mySessions,
      data: request.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, Session.fromJson);
  }

  @override
  Future<BulkCreateSessionResult> createBulk(
    BulkCreateSessionRequest request,
  ) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.sessionsBulk,
      data: request.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, BulkCreateSessionResult.fromJson);
  }

  @override
  Future<Session> update(String id, CreateSessionRequest request) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.session(id),
      data: request.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, Session.fromJson);
  }

  @override
  Future<void> updateImages(
    String id, {
    String? coverPhoto,
    String? coverPhotoPublicId,
    required List<String> images,
    required List<String> imagePublicIds,
  }) async {
    await _client.put<void>(
      ApiEndpoints.session(id),
      data: {
        'coverPhoto': coverPhoto,
        'coverPhotoPublicId': coverPhotoPublicId,
        'images': images,
        'imagePublicIds': imagePublicIds,
      },
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> cancel(String id) async {
    await _client.post<void>(
      ApiEndpoints.sessionCancel(id),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<Session> byId(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.session(id),
    );
    return unwrap(response.data, Session.fromJson);
  }

  @override
  Future<Page<Session>> recommendations(
    String sessionId, {
    required int limit,
    String? userId,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionRecommendations(sessionId),
      queryParameters: {'limit': limit, 'userId': ?userId},
    );
    // The rows are sessions plus `relevanceScore`/`matchReasons`/`distance`.
    // Only `distance` is rendered, and [Session] already carries it; the
    // scoring fields stay unmodelled until a screen shows them.
    return unwrapPage(response.data, Session.fromJson);
  }

  @override
  Future<void> startSession(String sessionId) async {
    await _client.post<void>(
      ApiEndpoints.sessionStart(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> endSession(String sessionId) async {
    await _client.post<void>(
      ApiEndpoints.sessionEnd(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<Match>> matches(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionMatches(sessionId),
    );
    final body = response.data ?? const <String, dynamic>{};
    final payload = body.containsKey('success') ? body['data'] : body;
    // Unlike every other match endpoint, this one wraps the list in
    // `{matches, totalMatches, filters}` rather than returning it bare.
    final map = payload as Map<String, dynamic>? ?? const {};
    final rows = map['matches'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(_normalizeMatchJson)
        .map(Match.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<PlayerStatistics>> playerStatistics(String sessionId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.sessionPlayerStatistics(sessionId),
    );
    final body = response.data ?? const <String, dynamic>{};
    final payload = body.containsKey('success') ? body['data'] : body;
    final map = payload as Map<String, dynamic>? ?? const {};
    final rows = map['playerStats'] as List<dynamic>? ?? const [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(PlayerStatistics.fromJson)
        .toList(growable: false);
  }

  @override
  Future<PlayerDetail> playerById(String playerId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.player(playerId),
    );
    return unwrap(response.data, PlayerDetail.fromJson);
  }

  @override
  Future<bool> showShuttlecockCount() async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.featureFlags,
    );
    final body = response.data ?? const <String, dynamic>{};
    final payload = body.containsKey('success') ? body['data'] : body;
    return payload is Map && payload['SHOW_SHUTTLECOCK_COUNT'] == true;
  }

  @override
  Future<void> updateRegistration(
    String sessionId,
    String playerId, {
    required bool approved,
  }) async {
    await _client.patch<void>(
      ApiEndpoints.sessionPlayerStatus(sessionId, playerId),
      data: {'status': approved ? 'APPROVED' : 'REJECTED'},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> toggleInactive(
    String sessionId,
    String playerId,
  ) async {
    await _client.patch<void>(
      ApiEndpoints.sessionPlayerToggleInactive(sessionId),
      data: {'playerId': playerId},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> removePlayer(String sessionId, String playerId) async {
    await _client.delete<void>(
      ApiEndpoints.sessionPlayer(sessionId, playerId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  /// The backend speaks the TypeScript enum's wire values, and `status` is one
  /// of the query parameters the OpenAPI document leaves untyped — so the
  /// mapping is written out rather than derived from the Dart enum name.
  String _statusParam(SessionStatus status) => switch (status) {
    SessionStatus.preparing => 'PREPARING',
    SessionStatus.inProgress => 'IN_PROGRESS',
    SessionStatus.finished => 'FINISHED',
    SessionStatus.cancelled => 'CANCELLED',
  };
}

/// `GET /sessions/:id/matches` parses `score`/`winnerIds` into real JSON
/// values before responding, unlike every other match endpoint (which leaves
/// them as the raw JSON-string column). Re-encode them back to a string so
/// [Match.fromJson] sees the same shape everywhere.
Map<String, dynamic> _normalizeMatchJson(Map<String, dynamic> json) {
  final normalized = Map<String, dynamic>.from(json);
  for (final key in const ['score', 'winnerIds']) {
    final value = normalized[key];
    if (value != null && value is! String) {
      normalized[key] = jsonEncode(value);
    }
  }
  return normalized;
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepositoryImpl(ref.watch(apiClientProvider)),
);
