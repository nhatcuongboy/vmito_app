import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Mirrors `UserRole` in `vmito-fe/src/lib/api/types.ts`.
@JsonEnum(alwaysCreate: true)
enum UserRole {
  @JsonValue('HOST')
  host,
  @JsonValue('GUEST')
  guest,
  @JsonValue('PLAYER')
  player,
  @JsonValue('ADMIN')
  admin,
  @JsonValue('REFEREE')
  referee,
}

/// The authenticated (or guest) user.
///
/// Ports `User` in `vmito-fe/src/types/auth.ts`. Every image field comes as an
/// `xxx` / `xxxPublicId` pair because uploads are proxied to Cloudinary by the
/// backend.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String email,
    required UserRole role,
    String? name,
    String? image,
    String? imagePublicId,
    String? coverPhoto,
    String? coverPhotoPublicId,
    String? phone,
    String? gender,

    // Guest-only. A guest has no JWT: identity is the player/session pair
    // obtained from a join code.
    String? playerId,
    String? sessionId,
    String? joinCode,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  const User._();

  bool get isGuest => role == UserRole.guest;
  bool get isHost => role == UserRole.host;
  bool get isAdmin => role == UserRole.admin;

  String get displayName => name?.trim().isNotEmpty ?? false ? name! : email;
}

/// `POST /auth/login` response.
@freezed
abstract class LoginResponse with _$LoginResponse {
  const factory LoginResponse({
    required String accessToken,
    required String refreshToken,
    required User user,
    String? tokenType,

    // The backend sends this as either a string ("7d") or a number, so it is
    // deliberately untyped rather than coerced.
    @JsonKey(name: 'expiresIn') dynamic expiresIn,
  }) = _LoginResponse;

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
}
