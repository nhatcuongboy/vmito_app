import 'package:freezed_annotation/freezed_annotation.dart';

part 'tournament_player.freezed.dart';
part 'tournament_player.g.dart';

/// A player on a tournament roster.
///
/// `level` stays an `int`: the backend's scale is non-contiguous (1–8, then
/// 9 = BEGINNER_MINUS, 10 = BEGINNER_PLUS), so an enum would silently reorder it.
@freezed
abstract class TournamentPlayer with _$TournamentPlayer {
  const factory TournamentPlayer({
    @JsonKey(defaultValue: '') required String id,
    @JsonKey(defaultValue: '') required String name,
    String? code,
    String? email,
    String? phone,
    String? image,
    String? imagePublicId,
    String? gender,
    int? level,
    String? levelDescription,
    String? notes,
    String? userId,
    @JsonKey(readValue: _readUserName) String? userName,
    @JsonKey(readValue: _readRegistrationCount, defaultValue: 0)
    @Default(0)
    int registrationCount,
    @JsonKey(readValue: _readPairCount, defaultValue: 0)
    @Default(0)
    int pairCount,
  }) = _TournamentPlayer;

  const TournamentPlayer._();

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) =>
      _$TournamentPlayerFromJson(json);

  bool matches(String query) => [name, code, email, phone, userName].any(
    (value) =>
        value?.toLowerCase().contains(query.trim().toLowerCase()) ?? false,
  );
}

Object? _readUserName(Map<dynamic, dynamic> json, String _) =>
    (json['user'] as Map<String, dynamic>?)?['name'];

Object? _readRegistrationCount(Map<dynamic, dynamic> json, String _) =>
    (json['_count'] as Map<String, dynamic>?)?['registrations'];

Object? _readPairCount(Map<dynamic, dynamic> json, String _) =>
    (json['_count'] as Map<String, dynamic>?)?['pairMembers'];
