import 'package:freezed_annotation/freezed_annotation.dart';

part 'pre_selected_slot.freezed.dart';
part 'pre_selected_slot.g.dart';

/// One pre-selected seat on a court: who, and in which slot.
///
/// **This is not a player.** `courts.preSelectedPlayers` is a `Json?` column
/// (`vmito-be/prisma/schema.prisma`) holding a raw `[{playerId, position}]`
/// array, and `GET /sessions/:id` spreads the court row so that array reaches
/// the client unresolved. Typing this field as a player list made
/// `SessionPlayer.fromJson` throw on its required `id` and took the whole
/// session-detail parse down with it.
///
/// Resolve to a real player by joining against `Session.players`.
@freezed
abstract class PreSelectedSlot with _$PreSelectedSlot {
  const factory PreSelectedSlot({
    required String playerId,
    @Default(0) int position,
  }) = _PreSelectedSlot;

  factory PreSelectedSlot.fromJson(Map<String, dynamic> json) =>
      _$PreSelectedSlotFromJson(json);
}
