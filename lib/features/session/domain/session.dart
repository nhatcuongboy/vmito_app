import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';

part 'session.freezed.dart';
part 'session.g.dart';

/// Mirrors `SessionStatus` in `vmito-fe/src/lib/api/types.ts`.
@JsonEnum(alwaysCreate: true)
enum SessionStatus {
  @JsonValue('PREPARING')
  preparing,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('FINISHED')
  finished,
  @JsonValue('CANCELLED')
  cancelled;

  bool get isLive => this == SessionStatus.inProgress;
  bool get isOpen =>
      this == SessionStatus.preparing || this == SessionStatus.inProgress;
}

/// The venue, at card level. The full venue model belongs to P7.
@freezed
abstract class SessionVenue with _$SessionVenue {
  const factory SessionVenue({
    required String id,
    String? name,

    /// Pre-merger district, which is what people still say out loud.
    String? district,

    /// Post-merger ward name. Present on newer records.
    String? newDistrict,
  }) = _SessionVenue;

  factory SessionVenue.fromJson(Map<String, dynamic> json) =>
      _$SessionVenueFromJson(json);

  const SessionVenue._();

  /// `Gò Vấp` — the old district reads better on a card than the new ward.
  String? get displayArea =>
      district?.trim().isNotEmpty ?? false ? district : newDistrict;
}

/// The host, as embedded in a session payload.
@freezed
abstract class SessionHost with _$SessionHost {
  const factory SessionHost({
    required String id,
    String? name,
    String? email,
    String? image,
  }) = _SessionHost;

  factory SessionHost.fromJson(Map<String, dynamic> json) =>
      _$SessionHostFromJson(json);
}

/// Player and court totals the API sends under `_count`.
@freezed
abstract class SessionCounts with _$SessionCounts {
  const factory SessionCounts({
    @Default(0) int players,
    @Default(0) int courts,
  }) = _SessionCounts;

  factory SessionCounts.fromJson(Map<String, dynamic> json) =>
      _$SessionCountsFromJson(json);
}

/// A session, at the level of detail the browse and detail-header screens need.
///
/// `ISession` on web has ~60 fields. This is deliberately not all of them:
/// fields are added when a screen renders them, so the model stays readable
/// and its JSON contract stays checkable. Court rosters, fee ledgers and the
/// crawled-post metadata belong to their own screens and their own models.
@freezed
abstract class Session with _$Session {
  const factory Session({
    required String id,
    required String name,
    required SessionStatus status,
    String? slug,
    String? description,
    String? location,
    SessionHost? host,
    String? hostName,
    String? coverPhoto,

    /// Configured court count. `counts.courts` is how many exist; these differ
    /// while a session is being set up.
    @Default(0) int numberOfCourts,
    @Default(0) int maxPlayersPerCourt,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? scheduledStartTime,
    DateTime? scheduledEndTime,
    @JsonKey(name: '_count') SessionCounts? counts,

    /// Present only when the caller sorted by distance. Kilometres.
    double? distance,

    /// Imported from a public Facebook post — view-only, no join flow.
    @Default(false) bool isCrawled,
    @Default(false) bool isFavorite,
    String? externalUrl,

    /// Empty means **all levels welcome** — never render that as a range.
    /// Order these with `sortByRank`, not `..sort()`: the ids are not in
    /// display order (9 = Yếu- sits below 1 = Yếu).
    @Default(<int>[]) List<int> requiredLevels,
    String? externalSource,
    SessionVenue? venue,

    // Detail-only. `GET /sessions/public` omits these; `GET /sessions/:id`
    // includes them. One model serves both rather than a parallel
    // SessionDetail that would drift from this one.
    @Default(<Court>[]) List<Court> courts,
    @Default(<SessionPlayer>[]) List<SessionPlayer> players,
    @Default(<SessionPlayer>[]) List<SessionPlayer> pendingPlayers,
    SessionFeeConfig? feeConfig,
    String? notes,
    String? hostPhone,
    @Default(false) bool allowGuestJoin,
    @Default(0) int sessionDuration,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  const Session._();

  int get playerCount => counts?.players ?? 0;

  /// Capacity as configured, not as filled. Zero when either factor is unset,
  /// which the UI must treat as "unknown" rather than "full".
  int get capacity => numberOfCourts * maxPlayersPerCourt;

  /// The time to show on a card: a running session has `startTime`, an
  /// upcoming one only has `scheduledStartTime`.
  DateTime? get displayStartTime => startTime ?? scheduledStartTime;

  String get displayHostName =>
      hostName?.trim().isNotEmpty ?? false ? hostName! : (host?.name ?? '');

  /// Crawled sessions have no host account to join through.
  bool get isJoinable => !isCrawled && status.isOpen;

  /// Courts sorted the way a human reads them. The API does not guarantee
  /// order, and an unsorted court board is disorienting on a live session.
  List<Court> get orderedCourts =>
      [...courts]..sort((a, b) => a.courtNumber.compareTo(b.courtNumber));

  List<SessionPlayer> get playingPlayers =>
      players.where((player) => player.isOnCourt).toList();

  List<SessionPlayer> get waitingPlayers =>
      players.where((player) => player.isWaiting).toList();

  /// `Hôm nay, 08:00-10:00`, or null when no time is set.
  ///
  /// Uses the **planned** end, not `endTime`. `endTime` is when the session
  /// actually stopped, which the backend sets on auto-end and which lands on
  /// ragged minutes — a card reading "21:00-23:38" looks like broken data. The
  /// planned window is also what a reader is comparing sessions on.
  String? get timeRangeLabel {
    final start = displayStartTime;
    if (start == null) return null;
    return Dates.dayWithRange(start, plannedEndTime);
  }

  /// Scheduled end, or start plus the configured duration, or the actual end.
  DateTime? get plannedEndTime {
    if (scheduledEndTime != null) return scheduledEndTime;
    final start = displayStartTime;
    if (start != null && sessionDuration > 0) {
      return start.add(Duration(minutes: sessionDuration));
    }
    return endTime;
  }

  /// `50k` or `50k-60k`, or null when the host has not priced the session.
  ///
  /// Reads male and female fixed fees as a range. Split-evenly sessions show
  /// their per-player amount once it exists — before that there is genuinely
  /// no number to give, and inventing one would mislead.
  String? get priceLabel {
    final fees = feeConfig;
    if (fees == null) return null;
    if (fees.isSplitEvenly) {
      final perPlayer = fees.splitPerPlayer;
      return perPlayer == null ? null : Money.compactVnd(perPlayer);
    }
    return Money.compactRange(fees.maleFee, fees.femaleFee);
  }

  /// `Sân Be Badminton • Gò Vấp`, falling back to the free-text location.
  ///
  /// The web card shows venue plus district rather than the full street
  /// address, which truncates to uselessness at card width.
  String get displayPlace {
    final venueName = venue?.name?.trim();
    final area = venue?.displayArea?.trim();
    if (venueName != null && venueName.isNotEmpty) {
      return area == null || area.isEmpty ? venueName : '$venueName • $area';
    }
    return location ?? '';
  }
}
