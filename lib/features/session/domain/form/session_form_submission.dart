import 'package:vmito_app/features/session/domain/bulk_create_session.dart';
import 'package:vmito_app/features/session/domain/create_session_request.dart';
import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_state.dart';
import 'package:vmito_app/features/session/domain/form/session_form_utils.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';

/// Turns validated form state into the request the backend accepts.
///
/// The one place that knows the wire shape depends on the form, so a field
/// added to the form has exactly one place to be wired through.
abstract final class SessionFormSubmission {
  static CreateSessionRequest toRequest(SessionFormState state) {
    final banner = state.bannerImage;
    final uploaded = state.uploadedImages;

    return CreateSessionRequest(
      name: state.name,
      sportType: state.sportType,
      location: _location(state),
      hostName: state.hostName,
      maxPlayersPerCourt: state.maxPlayersPerCourt,
      description: state.description,
      referenceVideoUrl: state.referenceVideoUrl,
      hostPhone: state.hostPhone,
      clubId: state.clubId,

      // Null leaves the field out of the body entirely. On a running session
      // the backend rejects changes to either group, and sending them anyway
      // turns a harmless edit into a 400.
      numberOfCourts: state.canEditCourts ? state.courts.length : null,
      courts: state.canEditCourts ? state.courts : null,
      sessionDuration: state.canEditTime ? state.durationMinutes : null,
      startTime: state.canEditTime ? state.startAt : null,
      endTime: state.canEditTime ? state.endAt : null,

      requirePlayerInfo: state.requirePlayerInfo,
      allowGuestJoin: state.allowGuestJoin,
      allowNewPlayers: state.allowNewPlayers,
      allowZaloContact: state.allowZaloContact,
      requiredLevels: state.effectiveRequiredLevels,
      courtColor: state.courtColor,
      defaultMatchType: state.defaultMatchType,
      shuttlecock: state.shuttlecock,
      coverPhoto: banner?.url,
      coverPhotoPublicId: banner?.publicId,
      images: [for (final image in uploaded) image.url!],
      imagePublicIds: [
        for (final image in uploaded)
          if (image.publicId != null) image.publicId!,
      ],
      feeConfig: state.feeConfig,
    );
  }

  static BulkCreateSessionRequest toBulkRequest(SessionFormState state) {
    final base = toRequest(state);
    return BulkCreateSessionRequest(
      mode: state.bulkMode,
      baseSession: base,
      // Each clone keeps the drafted time of day; only the date moves.
      specificDates: [
        for (final date in state.bulkDates) _withTimeOfDay(date, state),
      ],
      weekdays: state.bulkWeekdays,
      numberOfWeeks: state.bulkNumberOfWeeks,
      recurringStartDate: state.startAt,
    );
  }

  static DateTime _withTimeOfDay(DateTime date, SessionFormState state) {
    final start = state.startAt;
    if (start == null) return date;
    return DateTime(date.year, date.month, date.day, start.hour, start.minute);
  }

  static SessionLocationPayload _location(SessionFormState state) =>
      switch (state.locationKind) {
        SessionLocationKind.venue => VenueLocation(state.selectedVenueId),
        SessionLocationKind.custom => CustomLocation(
          name: state.customLocationName,
          address: state.customLocationAddress,
          placeId: state.customLocationPlaceId,
          lat: state.customLocationLat,
          lng: state.customLocationLng,
          district: state.customLocationDistrict,
          city: state.customLocationCity,
        ),
      };

  /// The images payload to copy onto the sibling sessions a bulk create made.
  ///
  /// `POST /sessions/bulk` does not carry the gallery to every clone, so the
  /// submit controller patches sessions 2..n afterwards — same as web.
  static CreateSessionRequest imageSyncRequest(
    SessionFormState state,
    CreateSessionRequest base,
  ) => base.copyWith();

  /// Clamps a bulk date to the window the backend and the picker agree on.
  static DateTime maxBulkDate(DateTime from) => DateTime(
    from.year,
    from.month + SessionFormUtils.cloneMaxMonthsAhead,
    from.day,
  );
}
