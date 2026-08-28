import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/core/location/address_display.dart';
import 'package:vmito_app/core/utils/formatters.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

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

@JsonEnum(alwaysCreate: true)
enum SessionSportType {
  @JsonValue('BADMINTON')
  badminton,
  @JsonValue('PICKLEBALL')
  pickleball,
}

/// The venue, at card level. The full venue model belongs to P7.
@freezed
abstract class SessionVenue with _$SessionVenue {
  const factory SessionVenue({
    required String id,
    String? name,

    /// Street address as entered. `newAddress` is the post-merger rewrite the
    /// backend derives; display it through [resolveAppAddress].
    String? address,
    String? newAddress,
    String? city,
    String? newCity,

    /// Pre-merger district, which is what people still say out loud.
    String? district,

    /// Post-merger ward name. Present on newer records.
    String? newDistrict,
    double? lat,
    double? lng,
  }) = _SessionVenue;

  factory SessionVenue.fromJson(Map<String, dynamic> json) =>
      _$SessionVenueFromJson(json);

  const SessionVenue._();

  String? displayAddress({required bool showNewAddress}) {
    final resolved = resolveAppAddress(
      showNewAddress: showNewAddress,
      address: address,
      district: district,
      city: city,
      newAddress: newAddress,
    );
    return resolved.isEmpty ? null : resolved.text;
  }
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

    /// Always present, unlike [host], which list payloads may omit.
    String? hostId,
    String? hostName,
    String? coverPhoto,

    String? coverPhotoPublicId,

    /// Gallery for the detail hero. Empty on most sessions, in which case the
    /// hero falls back to [coverPhoto] — see [galleryImages].
    @Default(<String>[]) List<String> images,

    /// Cloudinary ids parallel to [images]. The edit form needs them to send
    /// the gallery back unchanged; without them a re-save drops every id and
    /// orphans the assets.
    @Default(<String>[]) List<String> imagePublicIds,

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
    String? externalAuthorAvatar,
    @Default(SessionSportType.badminton) SessionSportType sportType,

    /// Empty means **all levels welcome** — never render that as a range.
    /// Order these with `sortByRank`, not `..sort()`: the ids are not in
    /// display order (9 = Yếu- sits below 1 = Yếu).
    @Default(<int>[]) List<int> requiredLevels,
    String? externalSource,
    SessionVenue? venue,

    /// Club the session is billed against, so members get the club's fixed fee
    /// automatically. Null means the session stands alone.
    String? clubId,

    /// `VENUE` when [venue] is the source of truth, `CUSTOM` when the host
    /// typed a one-off place into the seven `customLocation*` columns below.
    /// Null on older rows, which are all `VENUE`.
    String? locationType,

    // A place the host named themselves, stored flat rather than as a relation
    // because it belongs to this one session and is never looked up again.
    String? customLocationName,
    String? customLocationAddress,

    /// Google Places id, present only when the host picked a suggestion rather
    /// than typing free text.
    String? customLocationPlaceId,
    double? customLocationLat,
    double? customLocationLng,
    String? customLocationDistrict,
    String? customLocationCity,

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

    /// Whether a guest must supply name and level to register. The web form
    /// hides both of these behind a disabled section; they exist here so an
    /// edit round-trip does not reset what the web set.
    @Default(false) bool requirePlayerInfo,
    @Default(true) bool allowNewPlayers,

    /// Whether the host agreed to be contacted on Zalo. Gates the Zalo button
    /// only — the plain call button follows [hostPhone] alone.
    @Default(false) bool allowZaloContact,

    /// Free text, e.g. `Vina`. The host's shuttlecock brand for the session.
    String? shuttlecock,

    /// A clip the host wants players to watch — usually a YouTube link.
    String? referenceVideoUrl,
    @Default(0) int sessionDuration,

    /// What an empty court defaults to. Courts store no type of their own —
    /// see `Court.matchTypeOr`.
    @Default(MatchType.doubles) MatchType defaultMatchType,

    /// The host's court colour, as a CSS hex string. The backend defaults it,
    /// so this is only null on payloads that omit the field entirely.
    String? courtColor,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) =>
      _$SessionFromJson(json);

  const Session._();

  static const defaultCoverPhoto =
      'https://res.cloudinary.com/dzehhkd9m/image/upload/f_auto,q_auto,w_800,c_limit/v1778918839/badminton/session-covers/vtwinrsl4ffness0os42.jpg';

  int get playerCount => counts?.players ?? 0;

  /// Every image the hero can page through, cover photo included.
  ///
  /// The cover comes first, followed by distinct non-empty gallery images.
  List<String> get galleryImages {
    final gallery = <String>[];
    final seen = <String>{};

    void add(String? url) {
      final value = url?.trim();
      if (value == null || value.isEmpty || !seen.add(value)) return;
      gallery.add(value);
    }

    add(coverPhoto);
    images.forEach(add);
    return gallery;
  }

  /// Seats left, or null when [capacity] is unknown.
  ///
  /// Null and zero mean different things — "not configured" versus "full" —
  /// so this must not collapse them into a bare int.
  int? get availableSlots {
    if (capacity <= 0) return null;
    final left = capacity - playerCount;
    return left < 0 ? 0 : left;
  }

  bool get isFull => availableSlots == 0;

  /// Approved registrations only. [players] also carries pending rows once a
  /// host is looking at their own session.
  List<SessionPlayer> get approvedPlayers => players
      .where(
        (player) => player.registrationStatus == RegistrationStatus.approved,
      )
      .toList();

  /// Capacity as configured, not as filled. Zero when either factor is unset,
  /// which the UI must treat as "unknown" rather than "full".
  int get capacity => numberOfCourts * maxPlayersPerCourt;

  /// The time to show on a card: a running session has `startTime`, an
  /// upcoming one only has `scheduledStartTime`.
  DateTime? get displayStartTime => startTime ?? scheduledStartTime;

  String get displayHostName =>
      hostName?.trim().isNotEmpty ?? false ? hostName! : (host?.name ?? '');

  /// Crawled posts have no Vmito host account, but do carry the public
  /// Facebook author's avatar separately from [host].
  String? get displayHostImage {
    final image = isCrawled ? externalAuthorAvatar : host?.image;
    final value = image?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// The host's user account, or null when there is none to open — crawled
  /// Facebook sessions carry a name but no account.
  String? get hostAccountId {
    final id = host?.id ?? hostId;
    return id == null || id.trim().isEmpty || isCrawled ? null : id;
  }

  /// Crawled sessions have no host account to join through.
  bool get isJoinable => !isCrawled && status.isOpen;

  /// Courts sorted the way a human reads them. The API does not guarantee
  /// order, and an unsorted court board is disorienting on a live session.
  List<Court> get orderedCourts =>
      [...courts]..sort((a, b) => a.courtNumber.compareTo(b.courtNumber));

  List<SessionPlayer> get playingPlayers =>
      players.where((player) => player.isOnCourt).toList();

  /// Resolves a court's pre-selected seats into real players, in slot order.
  ///
  /// `Court.preSelectedPlayers` is only `{playerId, position}` — the backend
  /// stores it as raw JSON on the court row and never joins it. Ids with no
  /// matching roster entry are dropped rather than rendered as blanks.
  List<SessionPlayer> preSelectedPlayersFor(Court court) {
    final byId = {for (final player in players) player.id: player};
    final slots = [...court.preSelectedPlayers]
      ..sort((a, b) => a.position.compareTo(b.position));
    return [
      for (final slot in slots) ?byId[slot.playerId],
    ];
  }

  List<SessionPlayer> get waitingPlayers =>
      players.where((player) => player.isWaiting).toList();

  /// Who the host can actually put on a court next, longest wait first.
  ///
  /// Narrower than [waitingPlayers], which also counts READY players already
  /// assigned to a court. Mirrors `getWaitingPlayers` in
  /// `vmito-fe/src/utils/session-utils.ts` exactly, because the "need 4 players
  /// to assign" gate counts this list.
  List<SessionPlayer> get waitingQueue =>
      players.where((player) => player.status == PlayerStatus.waiting).toList()
        ..sort((a, b) => b.currentWaitTime.compareTo(a.currentWaitTime));

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
  String displayPlace({required bool showNewAddress}) {
    final venueName = venue?.name?.trim();
    final area = venue == null
        ? resolveCompactAddressArea(
            showNewAddress: showNewAddress,
            district: customLocationDistrict,
            city: customLocationCity,
          )
        : resolveCompactAddressArea(
            showNewAddress: showNewAddress,
            district: venue?.district,
            city: venue?.city,
            newDistrict: venue?.newDistrict,
            newCity: venue?.newCity,
          );
    if (venueName != null && venueName.isNotEmpty) {
      return area == null || area.isEmpty ? venueName : '$venueName • $area';
    }
    final rawLocation = location?.trim() ?? '';
    if (rawLocation.isEmpty) return '';
    return area == null || area.isEmpty ? rawLocation : '$rawLocation • $area';
  }

  bool get hasLocation =>
      (venue?.name?.trim().isNotEmpty ?? false) ||
      (location?.trim().isNotEmpty ?? false);
}
