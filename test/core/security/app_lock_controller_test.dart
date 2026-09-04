import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

import '../../support/fake_secure_storage.dart';

class _FakeAuthenticator implements BiometricAuthenticator {
  _FakeAuthenticator({
    this.result = const BiometricAuthResult.success(),
  });

  BiometricAuthResult result;
  int authenticationCount = 0;
  Completer<BiometricAuthResult>? pendingResult;

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) {
    authenticationCount++;
    return pendingResult?.future ?? Future.value(result);
  }

  @override
  Future<BiometricCapability> capability() async => const BiometricCapability(
    isAvailable: true,
    kind: BiometricKind.face,
  );
}

class _RestoreTracker {
  int calls = 0;
}

class _RestoringAuthController extends AuthController {
  _RestoringAuthController(this.tracker);

  final _RestoreTracker tracker;

  @override
  AuthState build() => const AuthState();

  @override
  Future<void> restoreSession() async {
    tracker.calls++;
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: User(
        id: 'user-1',
        email: 'user@example.com',
        role: UserRole.player,
      ),
    );
  }
}

({ProviderContainer container, BiometricLockStorage storage}) _container(
  _FakeAuthenticator authenticator,
) {
  final storage = BiometricLockStorage(FakeSecureStorage());
  final container = ProviderContainer(
    overrides: [
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
      biometricLockStorageProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(appLockControllerProvider.notifier)
      .bootstrap(enabled: false, hasSession: false);
  return (container: container, storage: storage);
}

void main() {
  test(
    'biometric storage defaults off and persists explicit changes',
    () async {
      final storage = BiometricLockStorage(FakeSecureStorage());

      expect(await storage.readEnabled(), isFalse);
      await storage.setEnabled(enabled: true);
      expect(await storage.readEnabled(), isTrue);
      await storage.clear();
      expect(await storage.readEnabled(), isFalse);
    },
  );

  test('enables only after successful device authentication', () async {
    final authenticator = _FakeAuthenticator();
    final (:container, :storage) = _container(authenticator);

    final result = await container
        .read(appLockControllerProvider.notifier)
        .enable(reason: 'Enable');

    expect(result.authenticated, isTrue);
    expect(container.read(appLockControllerProvider).enabled, isTrue);
    expect(await storage.readEnabled(), isTrue);
  });

  test('keeps the preference off when authentication is canceled', () async {
    final authenticator = _FakeAuthenticator(
      result: const BiometricAuthResult.failure(
        BiometricAuthFailure.canceled,
      ),
    );
    final (:container, :storage) = _container(authenticator);

    final result = await container
        .read(appLockControllerProvider.notifier)
        .enable(reason: 'Enable');

    expect(result.authenticated, isFalse);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
    expect(await storage.readEnabled(), isFalse);
  });

  test('disables only after a second successful authentication', () async {
    final authenticator = _FakeAuthenticator();
    final (:container, :storage) = _container(authenticator);
    final controller = container.read(appLockControllerProvider.notifier);
    await controller.enable(reason: 'Enable');

    final result = await controller.disable(reason: 'Disable');

    expect(result.authenticated, isTrue);
    expect(authenticator.authenticationCount, 2);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
    expect(await storage.readEnabled(), isFalse);
  });

  test('does not start a second authentication while one is pending', () async {
    final authenticator = _FakeAuthenticator()
      ..pendingResult = Completer<BiometricAuthResult>();
    final container = _container(authenticator).container;

    final first = container
        .read(appLockControllerProvider.notifier)
        .enable(reason: 'Enable');
    await Future<void>.delayed(Duration.zero);
    final second = await container
        .read(appLockControllerProvider.notifier)
        .enable(reason: 'Enable again');

    expect(second.authenticated, isFalse);
    expect(authenticator.authenticationCount, 1);
    authenticator.pendingResult!.complete(
      const BiometricAuthResult.success(),
    );
    await first;
  });

  test('locks only after the 30 second background grace period', () async {
    final container = _container(_FakeAuthenticator()).container;
    final controller = container.read(appLockControllerProvider.notifier);
    await controller.enable(reason: 'Enable');

    controller
      ..obscure()
      ..resume(backgroundDuration: const Duration(seconds: 29));
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.unlocked,
    );

    controller
      ..obscure()
      ..resume(backgroundDuration: const Duration(seconds: 30));
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.locked,
    );
  });

  test('backgrounding cannot turn an existing lock into an unlocked state', () {
    final container = _container(_FakeAuthenticator()).container;
    container.read(appLockControllerProvider.notifier)
      ..bootstrap(enabled: true, hasSession: true)
      ..obscure()
      ..resume(backgroundDuration: const Duration(seconds: 1));

    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.locked,
    );
  });

  test('restores an unresolved saved session only after unlocking', () async {
    final tracker = _RestoreTracker();
    final container = ProviderContainer(
      overrides: [
        biometricAuthenticatorProvider.overrideWithValue(_FakeAuthenticator()),
        biometricLockStorageProvider.overrideWithValue(
          BiometricLockStorage(FakeSecureStorage()),
        ),
        authControllerProvider.overrideWith(
          () => _RestoringAuthController(tracker),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(appLockControllerProvider.notifier)
        .bootstrap(enabled: true, hasSession: true);

    expect(tracker.calls, 0);
    await container
        .read(appLockControllerProvider.notifier)
        .unlock(reason: 'Unlock');

    expect(tracker.calls, 1);
    expect(
      container.read(appLockControllerProvider).status,
      AppLockStatus.unlocked,
    );
  });
}
