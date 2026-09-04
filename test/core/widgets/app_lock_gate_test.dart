import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/widgets/app_lock_gate.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _FakeAuthenticator implements BiometricAuthenticator {
  final List<BiometricAuthResult> results = [
    const BiometricAuthResult.success(),
  ];

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async =>
      results.removeAt(0);

  @override
  Future<BiometricCapability> capability() async => const BiometricCapability(
    isAvailable: true,
    kind: BiometricKind.face,
  );
}

class _AuthenticatedAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      email: 'user@example.com',
      role: UserRole.player,
    ),
  );

  @override
  Future<void> signOut() async {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

void main() {
  testWidgets(
    'shields immediately, applies the grace period, and offers safe escape',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var now = DateTime(2026, 9, 4, 10);
      final authenticator = _FakeAuthenticator();
      final container = ProviderContainer(
        overrides: [
          biometricAuthenticatorProvider.overrideWithValue(authenticator),
          biometricLockStorageProvider.overrideWithValue(
            BiometricLockStorage(FakeSecureStorage()),
          ),
          authControllerProvider.overrideWith(_AuthenticatedAuthController.new),
          appLockNowProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(appLockControllerProvider.notifier)
          .bootstrap(enabled: true, hasSession: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('vi'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: AppLockGate(child: Text('Nội dung riêng tư')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(appLockControllerProvider).status,
        AppLockStatus.unlocked,
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byKey(const Key('app-privacy-cover')), findsOneWidget);
      expect(find.text('Vmito đang bị khóa'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      now = now.add(const Duration(seconds: 29));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const Key('app-privacy-cover')), findsNothing);
      expect(find.text('Vmito đang bị khóa'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      now = now.add(const Duration(seconds: 30));
      authenticator.results.add(
        const BiometricAuthResult.failure(BiometricAuthFailure.canceled),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('app-lock-retry')), findsOneWidget);
      expect(find.byKey(const Key('app-lock-sign-out')), findsOneWidget);
      expect(find.text('Bạn đã hủy xác thực.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('app-lock-sign-out')));
      await tester.tap(find.byKey(const Key('app-lock-sign-out')));
      await tester.pumpAndSettle();
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      expect(container.read(appLockControllerProvider).enabled, isFalse);
    },
  );
}
