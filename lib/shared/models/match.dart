import 'package:freezed_annotation/freezed_annotation.dart';

part 'match.freezed.dart';
part 'match.g.dart';

/// Mirrors `MatchStatus` in `vmito-be/prisma/schema.prisma`.
@JsonEnum(alwaysCreate: true)
enum MatchStatus {
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('FINISHED')
  finished,
}

/// Whether a court is running singles or doubles.
///
/// Comes from `Session.defaultMatchType`; a court's live type is inferred from
/// how many players are on it, since the backend stores no per-court value.
@JsonEnum(alwaysCreate: true)
enum MatchType {
  @JsonValue('SINGLES')
  singles,
  @JsonValue('DOUBLES')
  doubles;

  /// 2 for singles, 4 for doubles.
  int get playerCount => this == MatchType.singles ? 2 : 4;
}

/// One player's seat in a match.
///
/// [position] is the authoritative court slot for a running match — the court's
/// own `courtPosition` is only used while a court is READY and no match exists.
@freezed
abstract class MatchPlayer with _$MatchPlayer {
  const factory MatchPlayer({
    required String id,
    required String playerId,
    @Default(0) int position,
    MatchPlayerRef? player,
  }) = _MatchPlayer;

  factory MatchPlayer.fromJson(Map<String, dynamic> json) =>
      _$MatchPlayerFromJson(json);
}

/// The trimmed player the match include carries.
///
/// `GET /sessions/:id` selects only these four fields on `currentMatch.players`
/// (`sessions.service.ts`), so this is deliberately not a full `SessionPlayer`.
@freezed
abstract class MatchPlayerRef with _$MatchPlayerRef {
  const factory MatchPlayerRef({
    required String id,
    String? name,
    int? playerNumber,
    int? courtPosition,
  }) = _MatchPlayerRef;

  factory MatchPlayerRef.fromJson(Map<String, dynamic> json) =>
      _$MatchPlayerRefFromJson(json);
}

/// A match on a court.
///
/// [startTime] is what drives the elapsed-time badge; it arrives with the court
/// on `GET /sessions/:id`, so no extra request is needed to run the timer.
@freezed
abstract class Match with _$Match {
  const factory Match({
    required String id,
    required String sessionId,
    required String courtId,
    @Default(MatchStatus.inProgress) MatchStatus status,
    DateTime? startTime,
    DateTime? endTime,
    @Default(<MatchPlayer>[]) List<MatchPlayer> players,

    /// **A string on the wire, not a list.** The column is `String?`
    /// (`schema.prisma`) holding serialized JSON; `vmito-fe`'s `types.ts`
    /// declares an array, which the API does not actually send.
    String? score,

    /// Same story as [score] — `String?`, not `string[]`.
    String? winnerIds,
    @Default(false) bool isDraw,
    String? notes,
    double? shuttlecockCount,
    @Default(false) bool isExtra,
  }) = _Match;

  factory Match.fromJson(Map<String, dynamic> json) => _$MatchFromJson(json);

  const Match._();

  bool get isRunning => status == MatchStatus.inProgress;

  /// Player ids in court-slot order.
  List<String> get orderedPlayerIds =>
      ([...players]..sort((a, b) => a.position.compareTo(b.position)))
          .map((player) => player.playerId)
          .toList(growable: false);
}
