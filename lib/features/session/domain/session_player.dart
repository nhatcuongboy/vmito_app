import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_player.freezed.dart';
part 'session_player.g.dart';

/// Mirrors `PlayerStatus` in `vmito-fe/src/lib/api/types.ts`.
@JsonEnum(alwaysCreate: true)
enum PlayerStatus {
  @JsonValue('WAITING')
  waiting,
  @JsonValue('PLAYING')
  playing,
  @JsonValue('FINISHED')
  finished,
  @JsonValue('READY')
  ready,
  @JsonValue('INACTIVE')
  inactive,
}

@JsonEnum(alwaysCreate: true)
enum Gender {
  @JsonValue('MALE')
  male,
  @JsonValue('FEMALE')
  female,
  @JsonValue('OTHER')
  other,
}

@JsonEnum(alwaysCreate: true)
enum RegistrationStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('APPROVED')
  approved,
  @JsonValue('REJECTED')
  rejected,
}

/// A player inside a session.
@freezed
abstract class SessionPlayer with _$SessionPlayer {
  const factory SessionPlayer({
    required String id,
    String? name,
    Gender? gender,

    /// **Always an `int`, never an enum.** The values are non-contiguous:
    /// 1-8, then 9 = `BEGINNER_MINUS`, 10 = `BEGINNER_PLUS`. A Dart enum would
    /// silently reorder them, so levels sort and compare as numbers.
    int? level,
    String? levelDescription,
    @Default(PlayerStatus.waiting) PlayerStatus status,
    int? playerNumber,
    String? currentCourtId,
    @Default(RegistrationStatus.approved) RegistrationStatus registrationStatus,
    String? phone,
    @Default(false) bool isJoined,

    /// Minutes since this player last came off court.
    @Default(0) int currentWaitTime,
    @Default(0) int totalWaitTime,
    @Default(0) int matchesPlayed,
  }) = _SessionPlayer;

  factory SessionPlayer.fromJson(Map<String, dynamic> json) =>
      _$SessionPlayerFromJson(json);

  const SessionPlayer._();

  /// The player's name, or null when they joined without one.
  ///
  /// No "Người chơi N" fallback here — see `Court.customName` for why a domain
  /// model must not build localized labels.
  String? get displayName =>
      name?.trim().isNotEmpty ?? false ? name!.trim() : null;

  bool get isOnCourt => status == PlayerStatus.playing;
  bool get isWaiting =>
      status == PlayerStatus.waiting || status == PlayerStatus.ready;
  bool get isPendingApproval =>
      registrationStatus == RegistrationStatus.pending;
}
