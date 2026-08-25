import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/social/domain/club.dart';

abstract final class ClubFeeControl {
  static const maleMonthly = 'maleMonthly';
  static const femaleMonthly = 'femaleMonthly';
  static const malePerSession = 'malePerSession';
  static const femalePerSession = 'femalePerSession';
}

FormGroup createClubFeeForm([ClubFeeConfig? config]) => FormGroup(
  {
    ClubFeeControl.maleMonthly: FormControl<int>(
      value: config?.maleFeeMonthly,
      validators: [Validators.delegate(_optionalNonNegative)],
    ),
    ClubFeeControl.femaleMonthly: FormControl<int>(
      value: config?.femaleFeeMonthly,
      validators: [Validators.delegate(_optionalNonNegative)],
    ),
    ClubFeeControl.malePerSession: FormControl<int>(
      value: config?.maleFeePerSession,
      validators: [Validators.delegate(_optionalNonNegative)],
    ),
    ClubFeeControl.femalePerSession: FormControl<int>(
      value: config?.femaleFeePerSession,
      validators: [Validators.delegate(_optionalNonNegative)],
    ),
  },
  validators: [Validators.delegate(_requiresPerSessionFee)],
);

Map<String, dynamic>? _optionalNonNegative(AbstractControl<dynamic> control) {
  final value = control.value;
  if (value == null) return null;
  return value is int && value >= 0 ? null : {'nonNegative': true};
}

Map<String, dynamic>? _requiresPerSessionFee(
  AbstractControl<dynamic> control,
) {
  if (control is! FormGroup) return null;
  final male = control.control(ClubFeeControl.malePerSession).value as int?;
  final female = control.control(ClubFeeControl.femalePerSession).value as int?;
  return male == null && female == null ? {'perSessionRequired': true} : null;
}

extension ClubFeeFormValue on FormGroup {
  int? clubFeeValue(String name) => control(name).value as int?;
}
