import 'package:vmito_app/features/session/domain/session_fee_config.dart';

/// The body of `POST /sessions`.
///
/// Hand-written rather than using the generated `CreateSessionDto`, for two
/// reasons that both matter here:
///
/// - every numeric field in the generated DTO is a `double` (the OpenAPI
///   document has no `type: integer` anywhere), and court counts and VND fees
///   must go over the wire as integers;
/// - the backend accepts ~30 optional fields covering venues, images, clubs
///   and crawled-post metadata. This carries only what the mobile create form
///   collects, so the request is readable and the omissions are deliberate
///   rather than accidental.
///
/// Fields the form does not set are left out of the JSON entirely — sending
/// explicit nulls would overwrite backend defaults.
class CreateSessionRequest {
  const CreateSessionRequest({
    required this.name,
    required this.numberOfCourts,
    required this.maxPlayersPerCourt,
    required this.sessionDuration,
    this.description,
    this.location,
    this.startTime,
    this.requiredLevels = const [],
    this.feeConfig,
    this.allowGuestJoin = true,
    this.allowNewPlayers = true,
    this.hostPhone,
  });

  final String name;
  final int numberOfCourts;
  final int maxPlayersPerCourt;

  /// Minutes. The backend derives `scheduledEndTime` from this.
  final int sessionDuration;

  final String? description;
  final String? location;
  final DateTime? startTime;

  /// Empty means **all levels welcome** — the backend treats an absent or
  /// empty list as no restriction, so it is sent only when non-empty.
  final List<int> requiredLevels;

  final SessionFeeConfig? feeConfig;
  final bool allowGuestJoin;
  final bool allowNewPlayers;
  final String? hostPhone;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'numberOfCourts': numberOfCourts,
    'maxPlayersPerCourt': maxPlayersPerCourt,
    'sessionDuration': sessionDuration,
    'allowGuestJoin': allowGuestJoin,
    'allowNewPlayers': allowNewPlayers,
    if (description?.trim().isNotEmpty ?? false)
      'description': description!.trim(),
    if (location?.trim().isNotEmpty ?? false) 'location': location!.trim(),
    if (hostPhone?.trim().isNotEmpty ?? false) 'hostPhone': hostPhone!.trim(),
    // The API speaks UTC ISO-8601; the form collects local wall time.
    if (startTime != null) 'startTime': startTime!.toUtc().toIso8601String(),
    if (requiredLevels.isNotEmpty) 'requiredLevels': requiredLevels,
    if (feeConfig != null) 'feeConfig': _feeConfigJson(feeConfig!),
  };

  static Map<String, dynamic> _feeConfigJson(SessionFeeConfig config) => {
    'feeType': config.isSplitEvenly ? 'SPLIT_EVENLY' : 'FIXED',
    // Amounts are integer VND with no minor units.
    if (config.maleFee != null) 'maleFee': config.maleFee,
    if (config.femaleFee != null) 'femaleFee': config.femaleFee,
  };
}
