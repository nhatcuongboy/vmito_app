import 'package:flutter_test/flutter_test.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:vmito_app/features/session/domain/form/browse_session_filter_form.dart';

FormGroup _form(String min, String max) => FormGroup(
  {
    BrowseFilterControl.minFee: FormControl<String>(value: min),
    BrowseFilterControl.maxFee: FormControl<String>(value: max),
  },
  validators: [Validators.delegate(validateBrowseFeeRange)],
);

void main() {
  test('accepts a non-negative ordered fee range', () {
    final form = _form('0', '200000');
    addTearDown(form.dispose);
    expect(form.valid, isTrue);
  });

  test('rejects negative, non-numeric and reversed fee ranges', () {
    for (final values in [('-1', '10'), ('abc', '10'), ('20', '10')]) {
      final form = _form(values.$1, values.$2);
      expect(form.invalid, isTrue);
      form.dispose();
    }
  });
}
