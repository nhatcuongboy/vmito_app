import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/form/session_form_state.dart';
import 'package:vmito_app/features/session/domain/form/session_form_utils.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_domain/vmito_domain.dart';

/// Ports `buildSessionFormDefaults` from
/// `vmito-fe/src/components/session/session-form/sessionFormDefaults.ts`.
abstract final class SessionFormDefaults {
  /// A blank form. [hostName] seeds the host field from the signed-in user,
  /// which is right almost every time and is trivially editable when it is not.
  static SessionFormState create({String? hostName}) => SessionFormState(
    isInitialized: true,
    hostName: hostName ?? '',
    courts: [SessionCourtDraft(key: nextDraftKey(), courtNumber: 1)],
    sessionDate: _today(),
  );

  /// Hydrates the form from a session being edited or cloned.
  ///
  /// A clone keeps everything about the session except its identity in time:
  /// the schedule resets so the host picks a new date, and court ids are
  /// dropped so the backend creates fresh courts instead of trying to move the
  /// original's — which would take its match history with it.
  static SessionFormState fromSession(
    Session session, {
    required bool isClone,
    String? hostName,
  }) {
    final hasVenue = session.venue != null;
    final start = isClone ? null : session.displayStartTime;
    final end = isClone ? null : session.plannedEndTime;
    final multiDay = SessionFormUtils.isMultiDay(start, end);

    return SessionFormState(
      isInitialized: true,
      isEditMode: !isClone,
      name: session.name,
      sportType: session.sportType,
      description: session.description ?? '',
      locationKind: hasVenue
          ? SessionLocationKind.venue
          : SessionLocationKind.custom,
      selectedVenueId: session.venue?.id ?? '',
      selectedVenueLabel: session.venue?.name ?? '',
      selectedVenueSublabel: session.venue?.displayAddress ?? '',

      // A session with a venue keeps no custom fields: leaving stale ones
      // around would resurrect an old address if the host switched to CUSTOM.
      customLocationName: hasVenue
          ? ''
          : (session.customLocationName ?? session.location ?? ''),
      customLocationAddress: hasVenue
          ? ''
          : (session.customLocationAddress ?? ''),
      customLocationPlaceId: hasVenue
          ? ''
          : (session.customLocationPlaceId ?? ''),
      customLocationLat: hasVenue ? null : session.customLocationLat,
      customLocationLng: hasVenue ? null : session.customLocationLng,
      customLocationDistrict: hasVenue
          ? ''
          : (session.customLocationDistrict ?? ''),
      customLocationCity: hasVenue ? '' : (session.customLocationCity ?? ''),

      hostName: session.hostName?.trim().isNotEmpty ?? false
          ? session.hostName!
          : (session.host?.name ?? hostName ?? ''),
      hostPhone: session.hostPhone ?? '',
      allowZaloContact: session.allowZaloContact,

      isMultiDay: multiDay,
      sessionDate: start == null
          ? _today()
          : DateTime(start.year, start.month, start.day),
      startTimeOfDay: start == null || multiDay
          ? null
          : SessionFormUtils.timeOfDay(start),
      endTimeOfDay: end == null || multiDay ? null : _endTimeOfDay(start!, end),
      multiDayStart: multiDay ? start : null,
      multiDayEnd: multiDay ? end : null,

      courts: _courtsFrom(session, isClone: isClone),
      // Only a session that has not started yet may have its courts or its
      // schedule rewritten; the backend rejects both otherwise.
      canEditCourts: isClone || session.status == SessionStatus.preparing,
      canEditTime: isClone || session.status != SessionStatus.inProgress,

      allLevelsSelected: session.requiredLevels.isEmpty,
      requiredLevels: sortByRank(session.requiredLevels),

      feeEnabled: session.feeConfig != null,
      feeType: session.feeConfig?.feeType ?? FeeType.fixed,
      maleFee: session.feeConfig?.maleFee,
      femaleFee: session.feeConfig?.femaleFee,
      feeNotes: session.feeConfig?.notes ?? '',

      images: _imagesFrom(session),
      bannerPublicId: session.coverPhotoPublicId,
      courtColor: session.courtColor ?? SessionFormUtils.courtColors.first,
      defaultMatchType: session.defaultMatchType,
      shuttlecock: session.shuttlecock ?? '',
      maxPlayersPerCourt: session.maxPlayersPerCourt > 0
          ? session.maxPlayersPerCourt
          : 8,
      referenceVideoUrl: session.referenceVideoUrl ?? '',
      clubId: session.clubId ?? '',

      requirePlayerInfo: session.requirePlayerInfo,
      allowGuestJoin: session.allowGuestJoin,
      allowNewPlayers: session.allowNewPlayers,
    );
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// A session ending at the midnight that closes its start day is one
  /// evening, not two days — its end time of day is 00:00, not 24:00.
  static Duration _endTimeOfDay(DateTime start, DateTime end) =>
      SessionFormUtils.isEndOfSelectedDay(start, end)
      ? Duration.zero
      : SessionFormUtils.timeOfDay(end);

  static List<SessionCourtDraft> _courtsFrom(
    Session session, {
    required bool isClone,
  }) {
    if (session.courts.isEmpty) {
      final count = session.numberOfCourts > 0 ? session.numberOfCourts : 1;
      return [
        for (var index = 0; index < count; index++)
          SessionCourtDraft(key: nextDraftKey(), courtNumber: index + 1),
      ];
    }
    return [
      for (final court in session.orderedCourts)
        SessionCourtDraft(
          key: nextDraftKey(),
          courtNumber: court.courtNumber,
          courtName: court.courtName ?? '',
          courtId: isClone ? null : court.id,
        ),
    ];
  }

  /// Rebuilds the gallery, cover photo first.
  ///
  /// `images` and `imagePublicIds` are parallel arrays and the cover may or may
  /// not also appear in them, so entries are de-duplicated by URL.
  static List<SessionImageDraft> _imagesFrom(Session session) {
    final drafts = <SessionImageDraft>[];
    final seen = <String>{};

    void add(String? url, String? publicId) {
      final trimmed = url?.trim();
      if (trimmed == null || trimmed.isEmpty || !seen.add(trimmed)) return;
      drafts.add(
        SessionImageDraft(
          key: nextDraftKey(),
          url: trimmed,
          publicId: publicId,
        ),
      );
    }

    add(session.coverPhoto, session.coverPhotoPublicId);
    for (var index = 0; index < session.images.length; index++) {
      add(
        session.images[index],
        index < session.imagePublicIds.length
            ? session.imagePublicIds[index]
            : null,
      );
    }
    return drafts;
  }
}
