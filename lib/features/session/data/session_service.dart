import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// Ports `vmito-fe/src/lib/api/session.service.ts`.
///
/// Only the browse endpoints so far. Add a method when a screen needs it —
/// the web service has far more, and porting it wholesale would be dead code
/// with an untested JSON contract.
class SessionService {
  const SessionService(this._client);

  final ApiClient _client;

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

  Future<Page<Session>> browseAvailable({
    required int limit,
    int page = 1,
    String? search,
    int? level,
    bool? hasSlots,
    String? sessionType,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.availableSessions,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty)
          'searchQuery': search.trim(),
        'level': ?level,
        'hasSlots': ?hasSlots,
        if (sessionType != null && sessionType != 'all')
          'sessionType': sessionType,
      },
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  /// Sessions this user hosts. Requires a token.
  ///
  /// The endpoint takes `hostId` rather than inferring it from the JWT, so an
  /// admin can list another host's sessions with the same call.
  Future<Page<Session>> hostedBy(
    String hostId, {
    required int limit,
    int page = 1,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.mySessions,
      queryParameters: {
        'hostId': hostId,
        'page': page,
        'limit': limit,
        'sortBy': 'startTime',
        'sortOrder': 'desc',
      },
    );
    return unwrapPage(response.data, Session.fromJson);
  }

  /// Creates a session and returns it as the backend stored it.
  ///
  /// Takes the already-built request rather than a long parameter list: the
  /// backend accepts 30 optional fields, and a positional signature here would
  /// be unreadable and easy to mis-order. See [CreateSessionRequest].
  Future<Session> create(CreateSessionRequest request) async {
    final response = await _client.post<Map<String, dynamic>>(
      ApiEndpoints.mySessions,
      data: request.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, Session.fromJson);
  }

  Future<Session> update(String id, CreateSessionRequest request) async {
    final response = await _client.put<Map<String, dynamic>>(
      ApiEndpoints.session(id),
      data: request.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, Session.fromJson);
  }

  Future<void> cancel(String id) async {
    await _client.post<void>(
      ApiEndpoints.sessionCancel(id),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<Session> byId(String id) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.session(id),
    );
    return unwrap(response.data, Session.fromJson);
  }

  Future<void> startSession(String sessionId) async {
    await _client.post<void>(
      ApiEndpoints.sessionStart(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> endSession(String sessionId) async {
    await _client.post<void>(
      ApiEndpoints.sessionEnd(sessionId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> selectPlayers(String courtId, List<String> playerIds) async {
    await _client.post<void>(
      ApiEndpoints.courtSelectPlayers(courtId),
      data: {'playerIds': playerIds},
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> deselectPlayers(String courtId) async {
    await _client.post<void>(
      ApiEndpoints.courtDeselectPlayers(courtId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> startMatch(String courtId) async {
    await _client.post<void>(
      ApiEndpoints.courtStartMatch(courtId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<void> endMatch(String courtId) async {
    await _client.post<void>(
      ApiEndpoints.courtEndMatch(courtId),
      data: const <String, dynamic>{},
      options: apiOptions(skipGlobalError: true),
    );
  }

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

final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(apiClientProvider)),
);
