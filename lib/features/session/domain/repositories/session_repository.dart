import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/domain/browse_session_filters.dart';
import 'package:vmito_app/features/session/domain/bulk_create_session.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/player_detail.dart';
import 'package:vmito_app/features/session/domain/player_statistics.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';
import 'package:vmito_app/shared/models/match.dart';

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
  });

  /// Sessions this user hosts.
  Future<Page<Session>> hostedBy(
    String hostId, {
    required int limit,
    int page = 1,
    SessionListQuery? query,
  });

  /// Sessions where the current user has a PENDING or APPROVED registration.
  Future<Page<Session>> joinedByCurrentUser(SessionListQuery query);

  Future<Page<PendingJoinRequest>> pendingJoinRequests({
    required int page,
    required int limit,
    String? search,
  });

  Future<int> pendingJoinRequestCount();

  Future<Session> create(CreateSessionRequest request);

  /// Clones one draft across several dates in a single call.
  ///
  /// Partial success is normal and is reported in the result rather than
  /// thrown — a date colliding with an existing session must not discard the
  /// dates that did work.
  Future<BulkCreateSessionResult> createBulk(BulkCreateSessionRequest request);

  Future<Session> update(String id, CreateSessionRequest request);

  Future<void> updateImages(
    String id, {
    String? coverPhoto,
    String? coverPhotoPublicId,
    required List<String> images,
    required List<String> imagePublicIds,
  });

  Future<void> cancel(String id);

  Future<Session> byId(String id);

  /// Sessions similar to [sessionId], ranked by the backend.
  ///
  /// [userId] personalises the ranking; omit it for a signed-out viewer.
  Future<Page<Session>> recommendations(
    String sessionId, {
    required int limit,
    String? userId,
  });

  Future<void> startSession(String sessionId);

  Future<void> endSession(String sessionId);

  /// Matches played in this session.
  ///
  /// Court *actions* live on `CourtRepository` — courts are their own backend
  /// resource — but match history belongs to the session that owns it.
  Future<List<Match>> matches(String sessionId);

  Future<List<PlayerStatistics>> playerStatistics(String sessionId);

  Future<PlayerDetail> playerById(String playerId);

  Future<bool> showShuttlecockCount();

  Future<void> updateRegistration(
    String sessionId,
    String playerId, {
    required bool approved,
  });

  Future<void> toggleInactive(String sessionId, String playerId);

  Future<void> removePlayer(String sessionId, String playerId);
}
