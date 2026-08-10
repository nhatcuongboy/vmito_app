import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_position.freezed.dart';
part 'player_position.g.dart';

/// One seat in a court assignment request: who sits in which slot.
///
/// Shared by `POST /courts/:id/select-players` (`SelectPlayersDto.players`) and
/// `POST /courts/:id/pre-select` (`PreSelectDto.playersWithPosition`) — the two
/// DTOs declare the same shape under different key names.
@freezed
abstract class PlayerPosition with _$PlayerPosition {
  const factory PlayerPosition({
    required String playerId,
    required int position,
  }) = _PlayerPosition;

  factory PlayerPosition.fromJson(Map<String, dynamic> json) =>
      _$PlayerPositionFromJson(json);
}
