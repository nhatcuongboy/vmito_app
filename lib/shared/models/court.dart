import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/pre_selected_slot.dart';
import 'package:vmito_app/shared/models/session_player.dart';

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

    /// The running match, when there is one. Carries `startTime`, which is what
    /// the elapsed-time badge counts from — no separate request needed.
    Match? currentMatch,

    /// Seats the host has picked for the *next* match but not yet started.
    ///
    /// Raw `{playerId, position}` pairs, not players — see [PreSelectedSlot].
    /// The court-call notification fires off this list.
    @Default(<PreSelectedSlot>[]) List<PreSelectedSlot> preSelectedPlayers,
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

  /// Singles or doubles, inferred from how many seats are taken.
  ///
  /// The backend stores no per-court match type — only `Session.defaultMatchType`
  /// — so an occupied court reports what it is actually running, and an empty
  /// one falls back to [fallback].
  MatchType matchTypeOr(MatchType fallback) {
    final occupied = currentPlayers.isNotEmpty
        ? currentPlayers.length
        : preSelectedPlayers.length;
    if (occupied == 0) return fallback;
    return occupied <= 2 ? MatchType.singles : MatchType.doubles;
  }

  /// Player ids on court in slot order, running match first.
  ///
  /// A running match owns the positions (`MatchPlayer.position`); a READY court
  /// has none yet, so the stored `courtPosition` is used instead.
  List<String> get orderedPlayerIds {
    final match = currentMatch;
    if (match != null && match.players.isNotEmpty) {
      return match.orderedPlayerIds;
    }
    final sorted = [...currentPlayers]
      ..sort((a, b) => a.slotPosition.compareTo(b.slotPosition));
    return sorted.map((player) => player.id).toList(growable: false);
  }
}
