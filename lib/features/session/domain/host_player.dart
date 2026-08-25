import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/shared/models/session_player.dart';

abstract final class HostPlayerFormControl {
  static const players = 'players';
  static const userId = 'userId';
  static const name = 'name';
  static const phone = 'phone';
  static const gender = 'gender';
  static const level = 'level';
  static const levelDescription = 'levelDescription';
  static const clubFeeEnabled = 'clubFeeEnabled';
  static const clubId = 'clubId';
}

class HostPlayerUserOption {
  const HostPlayerUserOption({
    required this.id,
    required this.name,
    required this.email,
    this.gender,
    this.level,
    this.levelDescription,
  });

  factory HostPlayerUserOption.fromJson(Map<String, dynamic> json) =>
      HostPlayerUserOption(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        gender: switch (json['gender']) {
          'FEMALE' => Gender.female,
          'OTHER' => Gender.other,
          'MALE' => Gender.male,
          _ => null,
        },
        level: (json['level'] as num?)?.toInt(),
        levelDescription: json['levelDescription'] as String?,
      );

  final String id;
  final String name;
  final String email;
  final Gender? gender;
  final int? level;
  final String? levelDescription;
}

class HostPlayerDraft {
  const HostPlayerDraft({
    this.userId,
    required this.name,
    required this.phone,
    required this.gender,
    required this.level,
    required this.levelDescription,
    required this.clubFeeEnabled,
    this.clubId,
  });

  factory HostPlayerDraft.fromForm(FormGroup form) => HostPlayerDraft(
    userId: form.control(HostPlayerFormControl.userId).value as String?,
    name: form.control(HostPlayerFormControl.name).value as String? ?? '',
    phone: form.control(HostPlayerFormControl.phone).value as String? ?? '',
    gender:
        form.control(HostPlayerFormControl.gender).value as Gender? ??
        Gender.male,
    level: form.control(HostPlayerFormControl.level).value as int?,
    levelDescription:
        form.control(HostPlayerFormControl.levelDescription).value as String? ??
        '',
    clubFeeEnabled:
        form.control(HostPlayerFormControl.clubFeeEnabled).value as bool? ??
        false,
    clubId: form.control(HostPlayerFormControl.clubId).value as String?,
  );

  final String? userId;
  final String name;
  final String phone;
  final Gender gender;
  final int? level;
  final String levelDescription;
  final bool clubFeeEnabled;
  final String? clubId;

  Map<String, dynamic> toJson() {
    final cleanUserId = userId?.trim();
    final cleanPhone = phone.trim();
    final cleanDescription = levelDescription.trim();
    final cleanClubId = clubId?.trim();
    return {
      'name': name.trim(),
      'gender': gender.wireValue,
      if (level != null) 'level': level,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      if (cleanDescription.isNotEmpty) 'levelDescription': cleanDescription,
      if (cleanUserId != null && cleanUserId.isNotEmpty) 'userId': cleanUserId,
      if (clubFeeEnabled && cleanClubId != null && cleanClubId.isNotEmpty) ...{
        'isClubMember': true,
        'clubId': cleanClubId,
      },
    };
  }
}

/// Form mapping for a single existing roster row.  Keep this separate from
/// [HostPlayerDraft]: edits must explicitly clear the club fields when the
/// fixed-fee option is turned off.
class HostPlayerEditDraft extends HostPlayerDraft {
  const HostPlayerEditDraft({
    super.userId,
    required super.name,
    required super.phone,
    required super.gender,
    required super.level,
    required super.levelDescription,
    required super.clubFeeEnabled,
    super.clubId,
  });

  factory HostPlayerEditDraft.fromForm(FormGroup form) => HostPlayerEditDraft(
    userId: form.control(HostPlayerFormControl.userId).value as String?,
    name: form.control(HostPlayerFormControl.name).value as String? ?? '',
    phone: form.control(HostPlayerFormControl.phone).value as String? ?? '',
    gender:
        form.control(HostPlayerFormControl.gender).value as Gender? ??
        Gender.male,
    level: form.control(HostPlayerFormControl.level).value as int?,
    levelDescription:
        form.control(HostPlayerFormControl.levelDescription).value as String? ??
        '',
    clubFeeEnabled:
        form.control(HostPlayerFormControl.clubFeeEnabled).value as bool? ??
        false,
    clubId: form.control(HostPlayerFormControl.clubId).value as String?,
  );

  @override
  Map<String, dynamic> toJson() {
    final data = super.toJson();
    // PATCH needs explicit values for optional fields that the host cleared.
    data['phone'] = phone.trim().isEmpty ? null : phone.trim();
    data
      ..['levelDescription'] = levelDescription.trim().isEmpty
          ? null
          : levelDescription.trim()
      ..['isClubMember'] = clubFeeEnabled
      ..['clubId'] = clubFeeEnabled ? clubId?.trim() : null;
    return data;
  }
}

FormGroup hostPlayerRowForm({int? defaultLevel}) => FormGroup(
  {
    HostPlayerFormControl.userId: FormControl<String>(),
    HostPlayerFormControl.name: FormControl<String>(
      validators: [Validators.required],
    ),
    HostPlayerFormControl.phone: FormControl<String>(),
    HostPlayerFormControl.gender: FormControl<Gender>(value: Gender.male),
    HostPlayerFormControl.level: FormControl<int>(
      value: defaultLevel,
      validators: [Validators.required],
    ),
    HostPlayerFormControl.levelDescription: FormControl<String>(),
    HostPlayerFormControl.clubFeeEnabled: FormControl<bool>(value: false),
    HostPlayerFormControl.clubId: FormControl<String>(),
  },
  validators: [Validators.delegate(_clubRequired)],
);

FormGroup hostPlayerEditForm(SessionPlayer player) => FormGroup(
  {
    HostPlayerFormControl.userId: FormControl<String>(value: player.userId),
    HostPlayerFormControl.name: FormControl<String>(
      value: player.name,
      validators: [Validators.required],
    ),
    HostPlayerFormControl.phone: FormControl<String>(value: player.phone),
    HostPlayerFormControl.gender: FormControl<Gender>(
      value: player.gender ?? Gender.male,
    ),
    HostPlayerFormControl.level: FormControl<int>(
      value: player.level,
      validators: [Validators.required],
    ),
    HostPlayerFormControl.levelDescription: FormControl<String>(
      value: player.levelDescription,
    ),
    HostPlayerFormControl.clubFeeEnabled: FormControl<bool>(
      value: player.clubId?.isNotEmpty ?? false,
    ),
    HostPlayerFormControl.clubId: FormControl<String>(value: player.clubId),
  },
  validators: [Validators.delegate(_clubRequired)],
);

Map<String, dynamic>? _clubRequired(AbstractControl<dynamic> control) {
  final group = control as FormGroup;
  final enabled =
      group.control(HostPlayerFormControl.clubFeeEnabled).value as bool? ??
      false;
  final clubId = group.control(HostPlayerFormControl.clubId).value as String?;
  return enabled && (clubId == null || clubId.trim().isEmpty)
      ? const {'clubRequired': true}
      : null;
}

extension GenderHostPlayerWireValue on Gender {
  String get wireValue => switch (this) {
    Gender.male => 'MALE',
    Gender.female => 'FEMALE',
    Gender.other => 'OTHER',
  };
}
