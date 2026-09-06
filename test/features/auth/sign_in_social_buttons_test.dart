import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/data/oauth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _CompletingBrowser {
  int calls = 0;
  String? lastUrl;

  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) async {
    calls += 1;
    lastUrl = url;
    return 'vmito://auth/callback?token=access&'
        'refreshToken=refresh&userId=user-1&email=a%40example.com&'
        'name=Player&role=PLAYER';
  }
}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  testWidgets('renders both providers and Google completes the app session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final browser = _CompletingBrowser();
    final container = ProviderContainer(
      overrides: [
        oauthAuthenticateProvider.overrideWithValue(browser.authenticate),
        tokenStorageProvider.overrideWithValue(
          TokenStorage(FakeSecureStorage()),
        ),
        biometricLockStorageProvider.overrideWithValue(
          BiometricLockStorage(FakeSecureStorage()),
        ),
      ],
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
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Tiếp tục với Google'), findsOneWidget);
    expect(find.bySemanticsLabel('Tiếp tục với Facebook'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('oauth-google')));
    await tester.pumpAndSettle();

    expect(browser.calls, 1);
    expect(Uri.parse(browser.lastUrl!).path, '/api/auth/google');
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(container.read(authControllerProvider).user?.id, 'user-1');
  });

  testWidgets('validates the email-or-phone field before submitting', (
    tester,
  ) async {
    final service = _MockAuthService();
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
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('signin-identifier-field')),
      'not-an-identifier',
    );
    await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
    await tester.pump();

    expect(find.text('Email hoặc số điện thoại không hợp lệ'), findsOneWidget);
    verifyNever(
      () => service.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('submits a valid phone number as the login identifier', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(
      () => service.login(email: '0912345678', password: 'Secret1!'),
    ).thenAnswer(
      (_) async => const LoginResponse(
        accessToken: 'access',
        refreshToken: 'refresh',
        user: User(
          id: 'user-1',
          email: 'player@example.com',
          role: UserRole.player,
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(service),
        tokenStorageProvider.overrideWithValue(
          TokenStorage(FakeSecureStorage()),
        ),
        biometricLockStorageProvider.overrideWithValue(
          BiometricLockStorage(FakeSecureStorage()),
        ),
      ],
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
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('signin-identifier-field')),
      '0912345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signin-password-field')),
      'Secret1!',
    );
    await tester.tap(find.byKey(const ValueKey('signin-submit-button')));
    await tester.pumpAndSettle();

    verify(
      () => service.login(email: '0912345678', password: 'Secret1!'),
    ).called(1);
  });
}
