/// A field the form can report an error against.
///
/// The order of the values **is** the scroll order used after a failed submit,
/// matching `scrollToFirstSessionError` on web. Reordering this enum changes
/// which field the screen jumps to.
enum SessionFormField {
  name,
  venue,
  customLocation,
  hostName,
  hostPhone,
  startTime,
  endTime,
  courts,
  maxPlayersPerCourt,
  referenceVideoUrl,
}

/// What is wrong with a field.
///
/// Codes rather than strings: this lives in `domain/`, which has no
/// `BuildContext` and therefore no `AppLocalizations`. Presentation maps these
/// through `SessionFormMessages`.
enum SessionFormErrorCode {
  sessionNameRequired,
  locationRequired,
  customLocationRequired,
  hostNameRequired,
  hostPhoneInvalid,
  startTimeRequired,
  endTimeRequired,
  startTimeMustBeInFuture,
  endTimeMustBeAfterStartTime,
  atLeastOneCourt,
  courtNumberMin,
  courtNumberUnique,
  maxPlayersPerCourtMin,
  maxPlayersPerCourtMax,
  referenceVideoUrlInvalid,
}

/// The outcome of validating the whole form.
class SessionFormErrors {
  const SessionFormErrors(this._byField);

  const SessionFormErrors.empty() : _byField = const {};

  final Map<SessionFormField, SessionFormErrorCode> _byField;

  bool get isEmpty => _byField.isEmpty;
  bool get isNotEmpty => _byField.isNotEmpty;

  SessionFormErrorCode? operator [](SessionFormField field) => _byField[field];

  bool has(SessionFormField field) => _byField.containsKey(field);

  /// Fields with errors, in the order the screen should scroll through them.
  List<SessionFormField> get orderedFields => [
    for (final field in SessionFormField.values)
      if (_byField.containsKey(field)) field,
  ];
}
