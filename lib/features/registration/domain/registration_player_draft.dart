import 'package:vmito_app/shared/models/session_player.dart';

/// One row of the registration form.
///
/// Ports `RegisterPlayerInput` from
/// `vmito-fe/src/components/session/useJoinSession.ts`. A registration is a
/// *list* of these — the web app has no "number of slots" field either; extra
/// slots are extra rows.
class RegistrationPlayerDraft {
  const RegistrationPlayerDraft({
    required this.isMe,
    this.name = '',
    this.phone = '',
    this.gender = Gender.male,
    this.level,
    this.levelDescription = '',
  });

  /// True for the row representing the signed-in user.
  ///
  /// This is the **only** thing that changes the payload: `userId` is sent for
  /// this row and omitted for every other. The backend reads that as
  /// "register me" versus "register a guest I'm bringing", and its duplicate
  /// guard only applies to the former.
  final bool isMe;

  final String name;
  final String phone;
  final Gender gender;

  /// Null means "not chosen yet". The form requires a value before submitting,
  /// mirroring the web app's `level === 0` check.
  final int? level;

  final String levelDescription;

  RegistrationPlayerDraft copyWith({
    String? name,
    String? phone,
    Gender? gender,
    int? level,
    String? levelDescription,
  }) => RegistrationPlayerDraft(
    isMe: isMe,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    gender: gender ?? this.gender,
    level: level ?? this.level,
    levelDescription: levelDescription ?? this.levelDescription,
  );

  /// The wire shape for one entry of `POST /sessions/:id/players/register`.
  ///
  /// [myUserId] is the signed-in user's id; it is written only when [isMe].
  /// Sending someone else's id is rejected by the backend, and sending *any*
  /// id on a guest row would trip the "already registered" guard.
  ///
  /// `playerNumber` is deliberately absent — the backend assigns it, and the
  /// web app's client-side guess is only ever a hint it then overrides.
  Map<String, dynamic> toRegisterJson(String? myUserId) {
    final trimmedPhone = phone.trim();
    final trimmedDescription = levelDescription.trim();

    return {
      'name': name.trim(),
      if (trimmedPhone.isNotEmpty) 'phone': trimmedPhone,
      'gender': gender.wireValue,
      if (level != null) 'level': level,
      if (trimmedDescription.isNotEmpty) 'levelDescription': trimmedDescription,
      if (isMe && myUserId != null) 'userId': myUserId,
    };
  }
}

/// The wire values for [Gender], which `@JsonValue` keeps private to the
/// generated serializer.
extension GenderWireValue on Gender {
  String get wireValue => switch (this) {
    Gender.male => 'MALE',
    Gender.female => 'FEMALE',
    Gender.other => 'OTHER',
  };
}
