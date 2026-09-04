import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _MockAuthService extends Mock implements AuthService {}

class _FakeAuthenticator implements BiometricAuthenticator {
  int prompts = 0;

  @override
  Future<BiometricCapability> capability() async =>
      const BiometricCapability(isAvailable: true, kind: BiometricKind.face);

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async {
    prompts += 1;
    return const BiometricAuthResult.success();
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required AuthService service,
  required BiometricAuthenticator authenticator,
  required FakeSecureStorage secureStorage,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final tokens = TokenStorage(secureStorage);
  await tokens.hydrate();

  final container = ProviderContainer(
    overrides: [
      authServiceProvider.overrideWithValue(service),
      tokenStorageProvider.overrideWithValue(tokens),
      biometricLockStorageProvider.overrideWithValue(
        BiometricLockStorage(secureStorage),
      ),
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
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
  return container;
}

Future<FakeSecureStorage> _armedStorage() async {
  final secureStorage = FakeSecureStorage();
  final tokens = TokenStorage(secureStorage);
  await tokens.save(accessToken: 'stale', refreshToken: 'refresh');
  await tokens.parkRefreshTokenForBiometrics();

  final lock = BiometricLockStorage(secureStorage);
  await lock.setEnabled(enabled: true);
  await lock.saveAccount(
    const BiometricAccount(
      userId: 'user-1',
      displayName: 'Nguyen Vu Nhat Cuong',
      email: 'cuong@vmito.app',
    ),
  );
  return secureStorage;
}

void main() {
  testWidgets('offers the saved account and signs in from a face scan', (
    tester,
  ) async {
    final service = _MockAuthService();
    when(() => service.refreshTokens('refresh')).thenAnswer(
      (_) async => const AuthTokens(
        accessToken: 'fresh',
        refreshToken: 'rotated',
      ),
    );
    when(service.currentUser).thenAnswer(
      (_) async => const User(
        id: 'user-1',
        email: 'cuong@vmito.app',
        name: 'Nguyen Vu Nhat Cuong',
        role: UserRole.player,
      ),
    );
    final authenticator = _FakeAuthenticator();

    final container = await _pump(
      tester,
      service: service,
      authenticator: authenticator,
      secureStorage: await _armedStorage(),
    );

    expect(find.text('Nguyen Vu Nhat Cuong'), findsOneWidget);
    expect(find.text('cuo•••@vmito.app'), findsOneWidget);

    await tester.tap(find.byKey(const Key('signin-biometric-button')));
    await tester.pumpAndSettle();

    expect(authenticator.prompts, 1);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  testWidgets('hides the shortcut when nothing is armed', (tester) async {
    await _pump(
      tester,
      service: _MockAuthService(),
      authenticator: _FakeAuthenticator(),
      secureStorage: FakeSecureStorage(),
    );

    expect(find.byKey(const Key('signin-biometric-button')), findsNothing);
    expect(find.byKey(const Key('biometric-switch-account')), findsNothing);
  });

  testWidgets('switching account drops the saved session', (tester) async {
    final secureStorage = await _armedStorage();
    await _pump(
      tester,
      service: _MockAuthService(),
      authenticator: _FakeAuthenticator(),
      secureStorage: secureStorage,
    );

    await tester.tap(find.byKey(const Key('biometric-switch-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('signin-biometric-button')), findsNothing);
    expect(await TokenStorage(secureStorage).readRefreshToken(), isNull);
  });
}
