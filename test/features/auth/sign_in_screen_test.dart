import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _MockAuthService extends Mock implements AuthService {}

Future<void> _pumpSignIn(
  WidgetTester tester, {
  required AuthService service,
  Locale locale = const Locale('vi'),
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
        locale: locale,
        home: const SignInScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'displays localized validation errors when fields are empty (vi)',
    (
      tester,
    ) async {
      final service = _MockAuthService();
      await _pumpSignIn(tester, service: service, locale: const Locale('vi'));

      await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
      await tester.pump();

      expect(
        find.text('Vui lòng nhập email'),
        findsOneWidget,
      );
      expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
      verifyNever(
        () => service.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets(
    'displays localized validation errors when fields are empty (en)',
    (
      tester,
    ) async {
      final service = _MockAuthService();
      await _pumpSignIn(tester, service: service, locale: const Locale('en'));

      await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
      await tester.pump();

      expect(
        find.text('Please enter your email'),
        findsOneWidget,
      );
      expect(find.text('Please enter your password'), findsOneWidget);
      verifyNever(
        () => service.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      );
    },
  );

  testWidgets('maps 401 ApiException to localized invalid credentials error', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(
      () => service.login(email: 'test@example.com', password: 'wrongpassword'),
    ).thenThrow(
      const ApiException(
        message: 'Invalid credentials',
        statusCode: 401,
        kind: ApiErrorKind.unauthorized,
      ),
    );

    await _pumpSignIn(tester, service: service, locale: const Locale('vi'));

    await tester.enterText(
      find.byKey(const ValueKey('signin-identifier-field')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signin-password-field')),
      'wrongpassword',
    );
    await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
    await tester.pumpAndSettle();

    expect(find.text('Thông tin đăng nhập không hợp lệ'), findsOneWidget);
  });

  testWidgets('maps 429 ApiException to localized too many requests error', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(
      () => service.login(email: 'test@example.com', password: 'password123'),
    ).thenThrow(
      const ApiException(
        message: 'Too Many Requests',
        statusCode: 429,
        kind: ApiErrorKind.server,
      ),
    );

    await _pumpSignIn(tester, service: service, locale: const Locale('vi'));

    await tester.enterText(
      find.byKey(const ValueKey('signin-identifier-field')),
      'test@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signin-password-field')),
      'password123',
    );
    await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
    await tester.pumpAndSettle();

    expect(
      find.text('Quá nhiều yêu cầu. Vui lòng thử lại sau.'),
      findsOneWidget,
    );
  });
}
