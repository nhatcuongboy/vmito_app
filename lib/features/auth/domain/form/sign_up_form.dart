import 'package:reactive_forms/reactive_forms.dart';

abstract final class SignUpFormControl {
  static const name = 'name';
  static const email = 'email';
  static const phone = 'phone';
  static const gender = 'gender';
  static const password = 'password';
  static const confirmPassword = 'confirmPassword';
  static const acceptedTerms = 'acceptedTerms';
}

final _strongPassword = RegExp(
  r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9\s])',
);

Map<String, dynamic>? _requiredTrimmed(AbstractControl<dynamic> control) {
  final value = control.value;
  if (value == null || (value is String && value.trim().isEmpty)) {
    return {ValidationMessage.required: true};
  }
  return null;
}

Map<String, dynamic>? _emailValidator(AbstractControl<dynamic> control) {
  final raw = control.value as String?;
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return null;
  return Validators.email(FormControl<String>(value: value));
}

Map<String, dynamic>? _strongPasswordValidator(
  AbstractControl<dynamic> control,
) {
  final value = control.value as String?;
  if (value == null || value.isEmpty) return null;
  return _strongPassword.hasMatch(value) ? null : {'weak': true};
}

FormGroup createSignUpForm() => FormGroup(
  {
    SignUpFormControl.name: FormControl<String>(
      validators: [Validators.delegate(_requiredTrimmed)],
    ),
    SignUpFormControl.email: FormControl<String>(
      validators: [
        Validators.delegate(_requiredTrimmed),
        Validators.delegate(_emailValidator),
      ],
    ),
    SignUpFormControl.phone: FormControl<String>(
      validators: [Validators.pattern(r'^\d{10}$')],
    ),
    SignUpFormControl.gender: FormControl<String>(),
    SignUpFormControl.password: FormControl<String>(
      validators: [
        Validators.required,
        Validators.minLength(8),
        Validators.delegate(_strongPasswordValidator),
      ],
    ),
    SignUpFormControl.confirmPassword: FormControl<String>(
      validators: [Validators.required],
    ),
    SignUpFormControl.acceptedTerms: FormControl<bool>(
      value: false,
      validators: [Validators.requiredTrue],
    ),
  },
  validators: [
    Validators.mustMatch(
      SignUpFormControl.password,
      SignUpFormControl.confirmPassword,
    ),
  ],
);
