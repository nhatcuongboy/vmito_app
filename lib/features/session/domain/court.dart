import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';

part 'court.freezed.dart';
part 'court.g.dart';

/// Mirrors `CourtStatus` in `vmito-fe/src/lib/api/types.ts`.
@JsonEnum(alwaysCreate: true)
enum CourtStatus {
  @JsonValue('EMPTY')
  empty,
  @JsonValue('IN_USE')
  inUse,
  @JsonValue('READY')
  ready,
}

/// Which way the court is drawn.
///
/// This must be a **coordinate transform** on one widget tree, never two
/// separate layouts — see docs/PORTING_GUIDE.md.
@JsonEnum(alwaysCreate: true)
enum CourtDirection {
  @JsonValue('HORIZONTAL')
  horizontal,
  @JsonValue('VERTICAL')
  vertical,
}

@freezed
abstract class Court with _$Court {
  const factory Court({
    required String id,
    required int courtNumber,
    @Default(CourtStatus.empty) CourtStatus status,
    @Default(CourtDirection.horizontal) CourtDirection direction,
    String? courtName,
    String? currentMatchId,
    @Default(<SessionPlayer>[]) List<SessionPlayer> currentPlayers,

    /// Players the host has picked but not yet started. The court-call
    /// notification fires off this list.
    @Default(<SessionPlayer>[]) List<SessionPlayer> preSelectedPlayers,
  }) = _Court;

  factory Court.fromJson(Map<String, dynamic> json) => _$CourtFromJson(json);

  const Court._();

  /// The host-given name, or null when there is none.
  ///
  /// Deliberately does not fall back to "Sân N": a domain model has no locale,
  /// and building the label here made a Vietnamese string appear in an English
  /// UI. The caller formats the number with `l10n.courtNumbered`.
  String? get customName =>
      courtName?.trim().isNotEmpty ?? false ? courtName!.trim() : null;

  bool get isPlaying => status == CourtStatus.inUse;
  bool get hasPreSelection => preSelectedPlayers.isNotEmpty;
}
