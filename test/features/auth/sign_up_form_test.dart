import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/domain/form/sign_up_form.dart';

void main() {
  group('sign-up form', () {
    test('accepts common non-alphanumeric password characters', () {
      final form = createSignUpForm();
      addTearDown(form.dispose);
      final password = form.control(SignUpFormControl.password);

      for (final value in ['Secret1#', 'Secret1_', 'Secret1+']) {
        password.value = value;
        expect(password.hasError('weak'), isFalse, reason: value);
      }
    });

    test('rejects a password without a special character', () {
      final form = createSignUpForm();
      addTearDown(form.dispose);
      final password = form.control(SignUpFormControl.password)
        ..value = 'Secret12';

      expect(password.hasError('weak'), isTrue);
    });

    test('keeps phone and gender optional', () {
      final form = createSignUpForm();
      addTearDown(form.dispose);

      expect(form.control(SignUpFormControl.phone).valid, isTrue);
      expect(form.control(SignUpFormControl.gender).valid, isTrue);
    });
  });
}
