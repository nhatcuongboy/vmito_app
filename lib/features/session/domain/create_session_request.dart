import 'package:vmito_app/features/session/domain/form/session_form_drafts.dart';
import 'package:vmito_app/features/session/domain/session_fee_config.dart';
import 'package:vmito_app/features/session/domain/session_location_payload.dart';
import 'package:vmito_app/shared/models/match.dart';

/// The body of `POST /sessions` and `PUT /sessions/:id`.
///
/// Hand-written rather than using the generated `CreateSessionDto`, because
/// every numeric field in that DTO is a `double` (the OpenAPI document has no
/// `type: integer` anywhere) and court counts and VND fees must go over the
/// wire as integers.
///
/// One type serves create and update, as it does on web. The difference is
/// which fields are populated: a running session cannot have its courts or its
/// times rewritten, so [courts], [numberOfCourts], [startTime], [endTime] and
/// [sessionDuration] are nullable and simply left out of the JSON. Everything
/// the form can edit is sent **explicitly, including empty strings and nulls**
/// — omitting `description` on an update would make it impossible to clear one.
class CreateSessionRequest {
  const CreateSessionRequest({
    required this.name,
    required this.location,
    required this.hostName,
    required this.maxPlayersPerCourt,
    this.description = '',
    this.referenceVideoUrl,
    this.hostPhone = '',
    this.clubId,
    this.numberOfCourts,
    this.sessionDuration,
    this.courts,
    this.startTime,
    this.endTime,
    this.requirePlayerInfo = false,
    this.allowGuestJoin = true,
    this.allowNewPlayers = true,
    this.allowZaloContact = false,
    this.requiredLevels = const [],
    this.courtColor,
    this.defaultMatchType = MatchType.doubles,
    this.shuttlecock = '',
    this.coverPhoto,
    this.coverPhotoPublicId,
    this.images = const [],
    this.imagePublicIds = const [],
    this.feeConfig,
  });

  final String name;

  /// Venue or one-off place. Exclusive by construction — see
  /// [SessionLocationPayload].
  final SessionLocationPayload location;

  final String hostName;
  final int maxPlayersPerCourt;
  final String description;

  /// Null clears the field. `''` would too, but the backend column is nullable
  /// and web sends null, so this matches.
  final String? referenceVideoUrl;
  final String hostPhone;
  final String? clubId;

  /// Null on an update that may not touch courts (session already running).
  final int? numberOfCourts;
  final List<SessionCourtDraft>? courts;

  /// Minutes. Null on an update that may not touch the schedule.
  final int? sessionDuration;
  final DateTime? startTime;
  final DateTime? endTime;

  final bool requirePlayerInfo;
  final bool allowGuestJoin;
  final bool allowNewPlayers;
  final bool allowZaloContact;

  /// Empty means **all levels welcome**. Sent even when empty: on an update it
  /// is how a host reopens a session they had restricted.
  final List<int> requiredLevels;

  final String? courtColor;
  final MatchType defaultMatchType;
  final String shuttlecock;
  final String? coverPhoto;
  final String? coverPhotoPublicId;
  final List<String> images;
  final List<String> imagePublicIds;
  final SessionFeeConfig? feeConfig;

  CreateSessionRequest copyWith({DateTime? startTime, DateTime? endTime}) =>
      CreateSessionRequest(
        name: name,
        location: location,
        hostName: hostName,
        maxPlayersPerCourt: maxPlayersPerCourt,
        description: description,
        referenceVideoUrl: referenceVideoUrl,
        hostPhone: hostPhone,
        clubId: clubId,
        numberOfCourts: numberOfCourts,
        sessionDuration: sessionDuration,
        courts: courts,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        requirePlayerInfo: requirePlayerInfo,
        allowGuestJoin: allowGuestJoin,
        allowNewPlayers: allowNewPlayers,
        allowZaloContact: allowZaloContact,
        requiredLevels: requiredLevels,
        courtColor: courtColor,
        defaultMatchType: defaultMatchType,
        shuttlecock: shuttlecock,
        coverPhoto: coverPhoto,
        coverPhotoPublicId: coverPhotoPublicId,
        images: images,
        imagePublicIds: imagePublicIds,
        feeConfig: feeConfig,
      );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description.trim(),
    'referenceVideoUrl': referenceVideoUrl?.trim().isNotEmpty ?? false
        ? referenceVideoUrl!.trim()
        : null,
    'hostName': hostName.trim(),
    'hostPhone': hostPhone.trim(),
    'clubId': clubId?.isNotEmpty ?? false ? clubId : null,
    'maxPlayersPerCourt': maxPlayersPerCourt,
    'requirePlayerInfo': requirePlayerInfo,
    'allowGuestJoin': allowGuestJoin,
    'allowNewPlayers': allowNewPlayers,
    'allowZaloContact': allowZaloContact,
    'requiredLevels': requiredLevels,
    if (courtColor != null) 'courtColor': courtColor,
    'defaultMatchType': defaultMatchType == MatchType.singles
        ? 'SINGLES'
        : 'DOUBLES',
    'shuttlecock': shuttlecock.trim(),
    if (coverPhoto != null) 'coverPhoto': coverPhoto,
    if (coverPhotoPublicId != null) 'coverPhotoPublicId': coverPhotoPublicId,
    'images': images,
    'imagePublicIds': imagePublicIds,
    if (numberOfCourts != null) 'numberOfCourts': numberOfCourts,
    if (courts != null) 'courts': [for (final court in courts!) court.toJson()],
    // The API speaks UTC ISO-8601; the form collects local wall time.
    if (startTime != null) 'startTime': startTime!.toUtc().toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toUtc().toIso8601String(),
    if (sessionDuration != null) 'sessionDuration': sessionDuration,
    'feeConfig': feeConfig == null ? null : _feeConfigJson(feeConfig!),
    ...location.toJson(),
  };

  static Map<String, dynamic> _feeConfigJson(SessionFeeConfig config) => {
    'feeType': config.isSplitEvenly ? 'SPLIT_EVENLY' : 'FIXED',
    // Amounts are integer VND with no minor units, and only a fixed-price
    // session has them — a split session's numbers are computed after it ends.
    if (!config.isSplitEvenly && config.maleFee != null)
      'maleFee': config.maleFee,
    if (!config.isSplitEvenly && config.femaleFee != null)
      'femaleFee': config.femaleFee,
    if (config.notes?.trim().isNotEmpty ?? false) 'notes': config.notes!.trim(),
  };
}
