import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_utils.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/shared/models/match.dart';

part 'session_form_state.freezed.dart';

/// Everything the create-session form holds, in one immutable value.
///
/// Deliberately **not** JSON-serialisable: this is form state, not a wire
/// type. `SessionFormSubmission` turns it into a `CreateSessionRequest`, and
/// that request is the only thing the backend ever sees.
///
/// Text lives here as plain strings, but the `TextEditingController`s do not —
/// they stay in the leaf widgets. Round-tripping every keystroke through an
/// immutable model breaks IME composition, which for Vietnamese telex input is
/// not a trade worth making.
@freezed
abstract class SessionFormState with _$SessionFormState {
  const factory SessionFormState({
    /// False until `initialize` has run. Guards against hydrating twice when
    /// the screen rebuilds before its first frame.
    @Default(false) bool isInitialized,
    @Default(false) bool isEditMode,

    // --- Basic info ---------------------------------------------------------
    @Default('') String name,
    @Default(SessionSportType.badminton) SessionSportType sportType,
    @Default('') String description,
    @Default(SessionLocationKind.venue) SessionLocationKind locationKind,
    @Default('') String selectedVenueId,

    /// Label for the selected venue, so the picker's trigger can render a name
    /// without holding the whole `Venue`. Set from the search result or from a
    /// `GET /venues/:id` when the AI picked one that was not in the list.
    @Default('') String selectedVenueLabel,
    @Default('') String selectedVenueSublabel,

    // --- Custom location ----------------------------------------------------
    @Default('') String customLocationName,
    @Default('') String customLocationAddress,
    @Default('') String customLocationPlaceId,
    double? customLocationLat,
    double? customLocationLng,
    @Default('') String customLocationDistrict,
    @Default('') String customLocationCity,

    /// True when the AI invented this place rather than matching a real venue.
    /// Drives the warning banner, and is retired for good once the host picks
    /// any venue from the list.
    @Default(false) bool customLocationFromAi,

    // --- Host ---------------------------------------------------------------
    @Default('') String hostName,
    @Default('') String hostPhone,
    @Default(false) bool allowZaloContact,

    // --- Time ---------------------------------------------------------------
    @Default(false) bool isMultiDay,

    /// The single-day date. Start and end times are [startTimeOfDay] and
    /// [endTimeOfDay]; in multi-day mode [startAt] and [endAt] are authoritative
    /// instead.
    DateTime? sessionDate,
    Duration? startTimeOfDay,
    Duration? endTimeOfDay,
    DateTime? multiDayStart,
    DateTime? multiDayEnd,

    // --- Courts -------------------------------------------------------------
    @Default(<SessionCourtDraft>[]) List<SessionCourtDraft> courts,

    /// False on an edit of a session that has already started — the backend
    /// rejects court changes then, and a form that lets a host try is a 400
    /// waiting to happen.
    @Default(true) bool canEditCourts,
    @Default(true) bool canEditTime,

    // --- Levels -------------------------------------------------------------
    @Default(true) bool allLevelsSelected,
    @Default(<int>[]) List<int> requiredLevels,

    // --- Fee ----------------------------------------------------------------
    @Default(false) bool feeEnabled,
    @Default(FeeType.fixed) FeeType feeType,
    int? maleFee,
    int? femaleFee,
    @Default('') String feeNotes,

    // --- Bulk ---------------------------------------------------------------
    @Default(false) bool bulkEnabled,
    @Default(BulkCreationMode.specificDates) BulkCreationMode bulkMode,
    @Default(<DateTime>[]) List<DateTime> bulkDates,

    /// Backend weekday numbering: 0 = Sunday.
    @Default(<int>[]) List<int> bulkWeekdays,
    @Default(4) int bulkNumberOfWeeks,

    // --- Advanced -----------------------------------------------------------
    @Default(<SessionImageDraft>[]) List<SessionImageDraft> images,

    /// The banner is tracked by publicId, not index: an index silently points
    /// at the wrong picture after a reorder or a delete.
    String? bannerPublicId,
    @Default('#179a3b') String courtColor,
    @Default(MatchType.doubles) MatchType defaultMatchType,
    @Default('') String shuttlecock,
    @Default(8) int maxPlayersPerCourt,
    @Default('') String referenceVideoUrl,
    @Default('') String clubId,
    @Default('') String clubLabel,

    // --- Fields with no control, preserved across an edit --------------------
    @Default(false) bool requirePlayerInfo,
    @Default(true) bool allowGuestJoin,
    @Default(true) bool allowNewPlayers,
  }) = _SessionFormState;

  const SessionFormState._();

  /// Start instant, whichever layout the time card is in.
  DateTime? get startAt {
    if (isMultiDay) return multiDayStart;
    final date = sessionDate;
    final time = startTimeOfDay;
    if (date == null || time == null) return null;
    return SessionFormUtils.combineDateTime(date, time);
  }

  /// End instant. In single-day mode a 00:00 end closes the day rather than
  /// preceding the start — see [SessionFormUtils.endDateTime].
  DateTime? get endAt {
    if (isMultiDay) return multiDayEnd;
    final date = sessionDate;
    final time = endTimeOfDay;
    if (date == null || time == null) return null;
    return SessionFormUtils.endDateTime(date, time);
  }

  int get durationMinutes => SessionFormUtils.durationMinutes(startAt, endAt);

  /// The band to send. Empty means all levels welcome, which is also what
  /// "All levels" resolves to.
  List<int> get effectiveRequiredLevels =>
      allLevelsSelected ? const [] : requiredLevels;

  List<SessionImageDraft> get uploadedImages =>
      images.where((image) => image.isReady).toList();

  /// The image to use as the cover, or null when there is none.
  ///
  /// Falls back to the first uploaded picture when the banner's id is gone —
  /// deleting the banner must not leave the session with no cover at all.
  SessionImageDraft? get bannerImage {
    final ready = uploadedImages;
    if (ready.isEmpty) return null;
    final banner = bannerPublicId;
    if (banner != null) {
      for (final image in ready) {
        if (image.publicId == banner) return image;
      }
    }
    return ready.first;
  }

  /// How many sessions the bulk card will create, for its footer count.
  int get bulkSessionCount => switch (bulkMode) {
    BulkCreationMode.specificDates => bulkDates.length,
    BulkCreationMode.recurringWeekdays =>
      bulkWeekdays.length * bulkNumberOfWeeks,
  };

  /// True when the submit should go to `POST /sessions/bulk`.
  bool get shouldCreateBulk => bulkEnabled && !isEditMode;

  SessionFeeConfig? get feeConfig => feeEnabled
      ? SessionFeeConfig(
          feeType: feeType,
          maleFee: feeType == FeeType.fixed ? maleFee : null,
          femaleFee: feeType == FeeType.fixed ? femaleFee : null,
          notes: feeNotes.trim().isEmpty ? null : feeNotes.trim(),
        )
      : null;
}
