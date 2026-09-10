import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

import '../../support/fake_secure_storage.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  test(
    'restores the hardcoded development user only when bypass is enabled',
    () async {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            TokenStorage(FakeSecureStorage()),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      final state = container.read(authControllerProvider);
      if (AppConfig.enableAuthBypass) {
        expect(state.status, AuthStatus.authenticated);
        expect(state.user?.id, 'development-bypass-user');
        expect(state.user?.role, UserRole.admin);
      } else {
        expect(state.status, AuthStatus.unauthenticated);
        expect(state.user, isNull);
      }
    },
  );

  test(
    'restores a persisted session after the app process restarts',
    () async {
      final secureStorage = FakeSecureStorage();
      await TokenStorage(
        secureStorage,
      ).save(accessToken: 'access', refreshToken: 'refresh');
      final restartedTokens = TokenStorage(secureStorage);
      final service = _MockAuthService();
      when(service.currentUser).thenAnswer(
        (_) async => const User(
          id: 'user-1',
          email: 'player@example.com',
          name: 'Player',
          role: UserRole.player,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(restartedTokens),
          authServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(container.read(authControllerProvider).user?.id, 'user-1');
      expect(restartedTokens.accessToken, 'access');
    },
    skip: AppConfig.enableAuthBypass,
  );

  test(
    'reconstructs a persisted session when only the refresh token remains',
    () async {
      final secureStorage = FakeSecureStorage({
        'vmito.refresh_token': 'refresh',
      });
      final restartedTokens = TokenStorage(secureStorage);
      final service = _MockAuthService();
      when(() => service.refreshTokens('refresh')).thenAnswer(
        (_) async => const AuthTokens(
          accessToken: 'fresh-access',
          refreshToken: 'rotated-refresh',
        ),
      );
      when(service.currentUser).thenAnswer(
        (_) async => const User(
          id: 'user-1',
          email: 'player@example.com',
          name: 'Player',
          role: UserRole.player,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(restartedTokens),
          authServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).restoreSession();

      expect(
        container.read(authControllerProvider).status,
        AuthStatus.authenticated,
      );
      expect(restartedTokens.accessToken, 'fresh-access');
      expect(await restartedTokens.readRefreshToken(), 'rotated-refresh');
    },
    skip: AppConfig.enableAuthBypass,
  );

  test('sign-out clears both tokens and biometric lock preference', () async {
    final secureStorage = FakeSecureStorage();
    final tokens = TokenStorage(secureStorage);
    final biometricLock = BiometricLockStorage(secureStorage);
    await tokens.save(accessToken: 'access', refreshToken: 'refresh');
    await biometricLock.setEnabled(enabled: true);
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        biometricLockStorageProvider.overrideWithValue(biometricLock),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).signOut();

    expect(tokens.hasAccessToken, isFalse);
    expect(await tokens.readRefreshToken(), isNull);
    expect(await biometricLock.readEnabled(), isFalse);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
  });

  test(
    'sign-out clears session data after authentication is removed',
    () async {
      final secureStorage = FakeSecureStorage();
      final tokens = TokenStorage(secureStorage);
      await tokens.save(accessToken: 'access', refreshToken: 'refresh');
      late final ProviderContainer container;
      AuthStatus? statusDuringCleanup;
      var cleanupCount = 0;
      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          biometricLockStorageProvider.overrideWithValue(
            BiometricLockStorage(secureStorage),
          ),
          sessionDataCleanupProvider.overrideWithValue(() {
            cleanupCount++;
            statusDuringCleanup = container.read(authControllerProvider).status;
          }),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(cleanupCount, 1);
      expect(statusDuringCleanup, AuthStatus.unauthenticated);
    },
  );

  test(
    "sign-out parks the refresh token out of the interceptor's reach",
    () async {
      final secureStorage = FakeSecureStorage();
      final tokens = TokenStorage(secureStorage);
      final biometricLock = BiometricLockStorage(secureStorage);
      await tokens.save(accessToken: 'access', refreshToken: 'refresh');
      await biometricLock.setEnabled(enabled: true);
      await biometricLock.saveAccount(
        const BiometricAccount(
          userId: 'user-1',
          displayName: 'Player',
          email: 'player@example.com',
        ),
      );
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(tokens),
          biometricLockStorageProvider.overrideWithValue(biometricLock),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).signOut();

      expect(tokens.hasAccessToken, isFalse);
      // The interceptor reads this key; leaving a token there would let a 401
      // on a public screen silently re-authenticate a signed-out user.
      expect(await tokens.readRefreshToken(), isNull);
      expect(await tokens.readBiometricRefreshToken(), 'refresh');
      expect(await biometricLock.readAccount(), isNotNull);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
    },
  );

  test('biometric sign-in exchanges the stored refresh token', () async {
    final secureStorage = FakeSecureStorage();
    final tokens = TokenStorage(secureStorage);
    final biometricLock = BiometricLockStorage(secureStorage);
    await tokens.save(accessToken: 'stale', refreshToken: 'refresh');
    await tokens.parkRefreshTokenForBiometrics();
    await biometricLock.setEnabled(enabled: true);

    final service = _MockAuthService();
    when(() => service.refreshTokens('refresh')).thenAnswer(
      (_) async => const AuthTokens(
        accessToken: 'fresh-access',
        refreshToken: 'rotated-refresh',
      ),
    );
    when(service.currentUser).thenAnswer(
      (_) async => const User(
        id: 'user-1',
        email: 'player@example.com',
        name: 'Player',
        role: UserRole.player,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        biometricLockStorageProvider.overrideWithValue(biometricLock),
        authServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authControllerProvider.notifier)
        .signInWithBiometrics();

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(tokens.accessToken, 'fresh-access');
    // The backend revokes the presented token, so the rotated one must land.
    expect(await tokens.readRefreshToken(), 'rotated-refresh');
    expect((await biometricLock.readAccount())?.userId, 'user-1');
  });

  test('a rejected refresh token withdraws the biometric offer', () async {
    final secureStorage = FakeSecureStorage();
    final tokens = TokenStorage(secureStorage);
    final biometricLock = BiometricLockStorage(secureStorage);
    await tokens.save(accessToken: 'stale', refreshToken: 'dead');
    await tokens.parkRefreshTokenForBiometrics();
    await biometricLock.setEnabled(enabled: true);
    await biometricLock.saveAccount(
      const BiometricAccount(
        userId: 'user-1',
        displayName: 'Player',
        email: 'player@example.com',
      ),
    );

    final service = _MockAuthService();
    when(() => service.refreshTokens('dead')).thenThrow(
      const ApiException(
        kind: ApiErrorKind.unauthorized,
        message: 'Refresh token revoked',
        statusCode: 401,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        biometricLockStorageProvider.overrideWithValue(biometricLock),
        authServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(authControllerProvider.notifier).signInWithBiometrics(),
      throwsA(isA<ApiException>()),
    );

    expect(await tokens.readRefreshToken(), isNull);
    expect(await tokens.readBiometricRefreshToken(), isNull);
    expect(await biometricLock.readEnabled(), isFalse);
    expect(await biometricLock.readAccount(), isNull);
  });
}
