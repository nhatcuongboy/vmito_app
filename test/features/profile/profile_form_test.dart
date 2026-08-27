import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/profile/domain/form/profile_form.dart';

void main() {
  group('profile form', () {
    test('requires a name and maps trimmed optional values', () {
      final form = createProfileForm(
        name: '',
        email: 'player@example.test',
        phone: ' 0912345678 ',
        gender: 'OTHER',
        level: 5,
        levelDescription: ' Cầu lông phong trào ',
      );
      addTearDown(form.dispose);

      expect(form.invalid, isTrue);
      form.control(ProfileFormControl.name).value = ' Nguyễn Văn A ';

      expect(ProfileDraft.fromForm(form).toJson(), {
        'name': 'Nguyễn Văn A',
        'phone': '0912345678',
        'gender': 'OTHER',
        'level': 5,
        'levelDescription': 'Cầu lông phong trào',
      });
    });

    test('maps cleared optional values to null', () {
      final form = createProfileForm(name: 'Player', email: 'p@example.test');
      addTearDown(form.dispose);

      expect(ProfileDraft.fromForm(form).toJson(), {
        'name': 'Player',
        'phone': null,
        'gender': null,
        'level': null,
        'levelDescription': null,
      });
    });
  });

  group('change password form', () {
    test('requires current password, strong new password, and a match', () {
      final form = createChangePasswordForm();
      addTearDown(form.dispose);

      form.control(ChangePasswordFormControl.currentPassword).value = 'old';
      form.control(ChangePasswordFormControl.newPassword).value = 'weak';
      form.control(ChangePasswordFormControl.confirmPassword).value = 'other';

      expect(form.invalid, isTrue);
      expect(
        form.control(ChangePasswordFormControl.newPassword).hasError('weak'),
        isTrue,
      );
      expect(
        form
            .control(ChangePasswordFormControl.confirmPassword)
            .hasError('mustMatch'),
        isTrue,
      );

      form.control(ChangePasswordFormControl.newPassword).value = 'Secret1!';
      form.control(ChangePasswordFormControl.confirmPassword).value =
          'Secret1!';
      expect(form.valid, isTrue);
    });
  });
}
