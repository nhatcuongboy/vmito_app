import 'package:reactive_forms/reactive_forms.dart';

abstract final class ProfileFormControl {
  static const name = 'name';
  static const email = 'email';
  static const phone = 'phone';
  static const gender = 'gender';
  static const level = 'level';
  static const levelDescription = 'levelDescription';
}

FormGroup createProfileForm({
  required String name,
  required String email,
  String? phone,
  String? gender,
  int? level,
  String? levelDescription,
}) => FormGroup({
  ProfileFormControl.name: FormControl<String>(
    value: name,
    validators: [Validators.required],
  ),
  ProfileFormControl.email: FormControl<String>(value: email, disabled: true),
  ProfileFormControl.phone: FormControl<String>(value: phone ?? ''),
  ProfileFormControl.gender: FormControl<String>(value: gender),
  ProfileFormControl.level: FormControl<int>(value: level),
  ProfileFormControl.levelDescription: FormControl<String>(
    value: levelDescription ?? '',
  ),
});

class ProfileDraft {
  const ProfileDraft({
    required this.name,
    this.phone,
    this.gender,
    this.level,
    this.levelDescription,
  });

  factory ProfileDraft.fromForm(FormGroup form) {
    String? optionalText(String controlName) {
      final value = form.control(controlName).value as String?;
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }

    return ProfileDraft(
      name: (form.control(ProfileFormControl.name).value as String).trim(),
      phone: optionalText(ProfileFormControl.phone),
      gender: form.control(ProfileFormControl.gender).value as String?,
      level: form.control(ProfileFormControl.level).value as int?,
      levelDescription: optionalText(ProfileFormControl.levelDescription),
    );
  }

  final String name;
  final String? phone;
  final String? gender;
  final int? level;
  final String? levelDescription;

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone': phone,
    'gender': gender,
    'level': level,
    'levelDescription': levelDescription,
  };
}

abstract final class ChangePasswordFormControl {
  static const currentPassword = 'currentPassword';
  static const newPassword = 'newPassword';
  static const confirmPassword = 'confirmPassword';
}

final RegExp _strongPassword = RegExp(
  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])',
);

Map<String, dynamic>? strongPasswordValidator(
  AbstractControl<dynamic> control,
) {
  final value = control.value as String?;
  if (value == null || value.isEmpty) return null;
  return _strongPassword.hasMatch(value) ? null : {'weak': true};
}

FormGroup createChangePasswordForm() => FormGroup(
  {
    ChangePasswordFormControl.currentPassword: FormControl<String>(
      validators: [Validators.required],
    ),
    ChangePasswordFormControl.newPassword: FormControl<String>(
      validators: [
        Validators.required,
        Validators.minLength(8),
        Validators.delegate(strongPasswordValidator),
      ],
    ),
    ChangePasswordFormControl.confirmPassword: FormControl<String>(
      validators: [Validators.required],
    ),
  },
  validators: [
    Validators.mustMatch(
      ChangePasswordFormControl.newPassword,
      ChangePasswordFormControl.confirmPassword,
    ),
  ],
);
