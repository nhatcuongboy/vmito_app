import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/profile/application/profile_controller.dart';
import 'package:vmito_app/features/profile/presentation/change_password_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeChangePasswordController extends ChangePasswordController {
  String? currentPassword;
  String? newPassword;

  @override
  ChangePasswordState build() => const ChangePasswordState();

  @override
  Future<bool> submit({
    required String currentPassword,
    required String newPassword,
  }) async {
    this.currentPassword = currentPassword;
    this.newPassword = newPassword;
    return false;
  }
}

void main() {
  testWidgets(
    'validates current, strong, and matching passwords before submit',
    (
      tester,
    ) async {
      final controller = _FakeChangePasswordController();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            changePasswordControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ChangePasswordScreen(),
          ),
        ),
      );

      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'weak',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password-field')),
        'different',
      );
      await tester.tap(
        find.byKey(const ValueKey('change-password-submit-button')),
      );
      await tester.pump();
      expect(controller.newPassword, isNull);
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      expect(
        find.text(
          'Dùng ít nhất 8 ký tự gồm chữ hoa, chữ thường, số và ký tự đặc biệt',
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('current-password-field')),
        'Current1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('new-password-field')),
        'Secret1!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('confirm-password-field')),
        'Secret1!',
      );
      await tester.tap(
        find.byKey(const ValueKey('change-password-submit-button')),
      );
      await tester.pump();

      expect(controller.currentPassword, 'Current1!');
      expect(controller.newPassword, 'Secret1!');
    },
  );
}
