import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_errors.dart';
import 'package:vmito_app/features/session/domain/form/session_form_state.dart';
import 'package:vmito_app/features/session/domain/form/session_form_utils.dart';

/// Lower and upper bounds on players per court, matching the web schema.
const int minPlayersPerCourt = 2;
const int maxPlayersPerCourtLimit = 12;

/// A start time may be this far in the past — the seconds between filling the
/// field and pressing submit should not invalidate it.
const Duration _startTimeGrace = Duration(seconds: 60);

/// Validates the whole form, ported from `sessionFormSchema.ts`.
///
/// A plain function rather than Flutter's `Form`/`FormField` for three reasons
/// the web schema makes unavoidable: `endTime > startTime` and the
/// venue-versus-custom requirement both read sibling fields, court numbers must
/// be unique across a dynamic array, and a failed submit needs the errors
/// **ordered** so the screen knows which field to scroll to. Validator closures
/// reading each other's state would make all three rebuild-order dependent.
///
/// [now] is injected so the "not in the past" rule is testable.
SessionFormErrors validateSessionForm(
  SessionFormState state, {
  required DateTime now,
}) {
  final errors = <SessionFormField, SessionFormErrorCode>{};

  if (state.name.trim().isEmpty) {
    errors[SessionFormField.name] = SessionFormErrorCode.sessionNameRequired;
  }

  switch (state.locationKind) {
    case SessionLocationKind.venue:
      if (state.selectedVenueId.trim().isEmpty) {
        errors[SessionFormField.venue] = SessionFormErrorCode.locationRequired;
      }
    case SessionLocationKind.custom:
      // Two characters, not one: a single letter is a slip, not a place.
      if (state.customLocationName.trim().length < 2) {
        errors[SessionFormField.customLocation] =
            SessionFormErrorCode.customLocationRequired;
      }
  }

  if (state.hostName.trim().isEmpty) {
    errors[SessionFormField.hostName] = SessionFormErrorCode.hostNameRequired;
  }

  if (!SessionFormUtils.isValidPhone(state.hostPhone)) {
    errors[SessionFormField.hostPhone] = SessionFormErrorCode.hostPhoneInvalid;
  }

  _validateSchedule(state, now: now, into: errors);
  _validateCourts(state, into: errors);

  if (state.maxPlayersPerCourt < minPlayersPerCourt) {
    errors[SessionFormField.maxPlayersPerCourt] =
        SessionFormErrorCode.maxPlayersPerCourtMin;
  } else if (state.maxPlayersPerCourt > maxPlayersPerCourtLimit) {
    errors[SessionFormField.maxPlayersPerCourt] =
        SessionFormErrorCode.maxPlayersPerCourtMax;
  }

  if (!SessionFormUtils.isValidVideoUrl(state.referenceVideoUrl)) {
    errors[SessionFormField.referenceVideoUrl] =
        SessionFormErrorCode.referenceVideoUrlInvalid;
  }

  return SessionFormErrors(errors);
}

void _validateSchedule(
  SessionFormState state, {
  required DateTime now,
  required Map<SessionFormField, SessionFormErrorCode> into,
}) {
  // A running session's schedule is not editable, so there is nothing to
  // check — and flagging a start time that is legitimately in the past would
  // block every edit of a live session.
  if (!state.canEditTime) return;

  final start = state.startAt;
  final end = state.endAt;

  if (start == null) {
    into[SessionFormField.startTime] = SessionFormErrorCode.startTimeRequired;
  } else if (!state.isEditMode &&
      start.isBefore(now.subtract(_startTimeGrace))) {
    into[SessionFormField.startTime] =
        SessionFormErrorCode.startTimeMustBeInFuture;
  }

  if (end == null) {
    into[SessionFormField.endTime] = SessionFormErrorCode.endTimeRequired;
  } else if (start != null && !end.isAfter(start)) {
    into[SessionFormField.endTime] =
        SessionFormErrorCode.endTimeMustBeAfterStartTime;
  }
}

void _validateCourts(
  SessionFormState state, {
  required Map<SessionFormField, SessionFormErrorCode> into,
}) {
  if (!state.canEditCourts) return;

  final courts = state.courts;
  if (courts.isEmpty) {
    into[SessionFormField.courts] = SessionFormErrorCode.atLeastOneCourt;
    return;
  }
  if (courts.any((court) => court.courtNumber < 1)) {
    into[SessionFormField.courts] = SessionFormErrorCode.courtNumberMin;
    return;
  }
  final numbers = <int>{for (final court in courts) court.courtNumber};
  if (numbers.length != courts.length) {
    into[SessionFormField.courts] = SessionFormErrorCode.courtNumberUnique;
  }
}
