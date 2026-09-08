import 'package:reactive_forms/reactive_forms.dart';

abstract final class BrowseFilterControl {
  static const date = 'date';
  static const timeRanges = 'timeRanges';
  static const hasSlots = 'hasSlots';
  static const nearMe = 'nearMe';
  static const source = 'source';
  static const city = 'city';
  static const districts = 'districts';
  static const sports = 'sports';
  static const levels = 'levels';
  static const minFee = 'minFee';
  static const maxFee = 'maxFee';
  static const splitEvenly = 'splitEvenly';
}

Map<String, dynamic>? validateBrowseFeeRange(
  AbstractControl<dynamic> control,
) {
  final group = control as FormGroup;
  final min = _feeValue(group.control(BrowseFilterControl.minFee).value);
  final max = _feeValue(group.control(BrowseFilterControl.maxFee).value);
  if (min == null || max == null || min < 0 || max < 0) {
    return {'invalidFee': true};
  }
  return min <= max ? null : {'feeRange': true};
}

int? _feeValue(Object? value) => switch (value) {
  int value => value,
  String value =>
    int.tryParse(value.trim()) ??
        int.tryParse(value.replaceAll(RegExp('[^0-9]'), '')),
  _ => null,
};
