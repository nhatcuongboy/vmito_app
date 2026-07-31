import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// The `Session` entity's data boundary. `presentation/` and `application/`
/// depend on this, never on `SessionRepositoryImpl` or `ApiClient` directly.
///
/// Covers the whole `Session` resource, not just the player-facing screens —
/// host-management and payment controllers depend on this same interface,
/// same as they would depend on any other feature's domain layer.
abstract interface class SessionRepository {
  /// Public session browse. Requires no token, which is deliberate: App Store
  /// guideline 5.1.1(i) forbids gating browsing behind registration.
  Future<Page<Session>> browsePublic({
    required int limit,
    int page = 1,
    String? search,
    SessionStatus? status,
  });

  Future<Page<Session>> browseAvailable({
    required int limit,
    int page = 1,
    String? search,
    int? level,
    bool? hasSlots,
    String? sessionType,
  });

  /// Sessions this user hosts.
  Future<Page<Session>> hostedBy(String hostId, {required int limit, int page = 1});

  Future<Session> create(CreateSessionRequest request);

  Future<Session> update(String id, CreateSessionRequest request);

  Future<void> cancel(String id);

  Future<Session> byId(String id);

  Future<void> startSession(String sessionId);

  Future<void> endSession(String sessionId);

  Future<void> selectPlayers(String courtId, List<String> playerIds);

  Future<void> deselectPlayers(String courtId);

  Future<void> startMatch(String courtId);

  Future<void> endMatch(String courtId);

  Future<void> updateRegistration(
    String sessionId,
    String playerId, {
    required bool approved,
  });

  Future<void> toggleInactive(String sessionId, String playerId);

  Future<void> removePlayer(String sessionId, String playerId);
}
