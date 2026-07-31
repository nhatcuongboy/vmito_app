import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/password_reset.dart';
import 'package:vmito_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:vmito_app/features/auth/presentation/reset_password_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required AuthService service,
  required Widget child,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [authServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('vi'),
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets(
    'forgot password validates email and shows privacy-safe success',
    (
      tester,
    ) async {
      final service = _MockAuthService();
      when(
        () => service.forgotPassword(
          email: 'player@example.com',
          locale: 'vi',
          redirectUrl: 'https://vmito.com/vi/auth/reset-password',
        ),
      ).thenAnswer((_) async {});

      await _pumpScreen(
        tester,
        service: service,
        child: const ForgotPasswordScreen(),
      );

      await tester.tap(find.byKey(const ValueKey('forgot-submit-button')));
      await tester.pump();
      expect(find.text('Vui lòng nhập email'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('forgot-email-field')),
        'player@example.com',
      );
      await tester.tap(find.byKey(const ValueKey('forgot-submit-button')));
      await tester.pumpAndSettle();

      verify(
        () => service.forgotPassword(
          email: 'player@example.com',
          locale: 'vi',
          redirectUrl: 'https://vmito.com/vi/auth/reset-password',
        ),
      ).called(1);
      expect(
        find.textContaining('Nếu email này hợp lệ'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('forgot-email-field')), findsNothing);
    },
  );

  testWidgets('reset password verifies token and rejects mismatched values', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(() => service.verifyResetToken('valid-token')).thenAnswer(
      (_) async => const PasswordResetTokenStatus(
        valid: true,
        maskedEmail: 'p***@example.com',
      ),
    );
    when(
      () => service.resetPassword(
        token: 'valid-token',
        newPassword: 'secret1',
      ),
    ).thenAnswer((_) async {});

    await _pumpScreen(
      tester,
      service: service,
      child: const ResetPasswordScreen(token: 'valid-token'),
    );

    expect(find.textContaining('p***@example.com'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('reset-password-field')),
      'secret1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-field')),
      'different',
    );
    await tester.tap(find.byKey(const ValueKey('reset-submit-button')));
    await tester.pump();
    expect(find.text('Mật khẩu không khớp'), findsOneWidget);
    verifyNever(
      () => service.resetPassword(
        token: any(named: 'token'),
        newPassword: any(named: 'newPassword'),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('reset-confirm-field')),
      'secret1',
    );
    await tester.tap(find.byKey(const ValueKey('reset-submit-button')));
    await tester.pumpAndSettle();

    verify(
      () => service.resetPassword(
        token: 'valid-token',
        newPassword: 'secret1',
      ),
    ).called(1);
    expect(find.textContaining('đã được đặt lại thành công'), findsOneWidget);
  });

  testWidgets('reset password rejects a missing token without calling API', (
    tester,
  ) async {
    final service = _MockAuthService();
    await _pumpScreen(
      tester,
      service: service,
      child: const ResetPasswordScreen(token: ''),
    );

    expect(find.textContaining('thiếu mã xác thực'), findsOneWidget);
    verifyNever(() => service.verifyResetToken(any()));
  });
}
