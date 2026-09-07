import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/profile/presentation/account_security_screen.dart';
import 'package:vmito_app/features/profile/presentation/change_password_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _FakeAuthenticator implements BiometricAuthenticator {
  _FakeAuthenticator({
    required this.capabilityValue,
    this.result = const BiometricAuthResult.success(),
  });

  final BiometricCapability capabilityValue;
  BiometricAuthResult result;

  @override
  Future<BiometricAuthResult> authenticate({required String reason}) async =>
      result;

  @override
  Future<BiometricCapability> capability() async => capabilityValue;
}

Future<ProviderContainer> _pumpScreen(
  WidgetTester tester,
  _FakeAuthenticator authenticator, {
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final container = ProviderContainer(
    overrides: [
      biometricAuthenticatorProvider.overrideWithValue(authenticator),
      biometricLockStorageProvider.overrideWithValue(
        BiometricLockStorage(FakeSecureStorage()),
      ),
    ],
  );
  addTearDown(container.dispose);
  container
      .read(appLockControllerProvider.notifier)
      .bootstrap(enabled: false, hasSession: false);
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.accountSecurity,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) => Scaffold(body: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (_, _) => const Scaffold(),
                routes: [
                  GoRoute(
                    path: 'account-security',
                    name: AppRoutes.nameAccountSecurity,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => const AccountSecurityScreen(),
                    routes: [
                      GoRoute(
                        path: 'change-password',
                        name: AppRoutes.nameChangePassword,
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (_, _) => const ChangePasswordScreen(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        locale: const Locale('vi'),
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('opens the change-password form from account security', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeAuthenticator(
        capabilityValue: const BiometricCapability.unavailable(),
      ),
    );

    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('current-password-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('new-password-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('confirm-password-field')),
      findsOneWidget,
    );
  });

  testWidgets('shows Face ID label and enables the lock after authentication', (
    tester,
  ) async {
    final container = await _pumpScreen(
      tester,
      _FakeAuthenticator(
        capabilityValue: const BiometricCapability(
          isAvailable: true,
          kind: BiometricKind.face,
        ),
      ),
    );

    expect(find.text('Đăng nhập bằng Face ID'), findsOneWidget);
    await tester.tap(find.byKey(const Key('biometric-lock-toggle')));
    await tester.pumpAndSettle();

    expect(container.read(appLockControllerProvider).enabled, isTrue);
    expect(
      find.text(
        'Đăng nhập mà không cần nhập mật khẩu, và xác thực lại khi bạn quay '
        'lại Vmito sau 30 giây.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('disables the switch when no biometrics are enrolled', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      _FakeAuthenticator(
        capabilityValue: const BiometricCapability.unavailable(),
      ),
    );

    final switchFinder = find.descendant(
      of: find.byKey(const Key('biometric-lock-toggle')),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(switchFinder).onChanged, isNull);
    expect(
      find.textContaining('Hãy thiết lập nhận diện khuôn mặt'),
      findsOneWidget,
    );
  });

  testWidgets('keeps the switch off and reports a canceled authentication', (
    tester,
  ) async {
    final authenticator = _FakeAuthenticator(
      capabilityValue: const BiometricCapability(
        isAvailable: true,
        kind: BiometricKind.fingerprint,
      ),
      result: const BiometricAuthResult.failure(
        BiometricAuthFailure.canceled,
      ),
    );
    final container = await _pumpScreen(tester, authenticator);

    await tester.tap(find.byKey(const Key('biometric-lock-toggle')));
    await tester.pumpAndSettle();

    expect(container.read(appLockControllerProvider).enabled, isFalse);
    expect(find.text('Bạn đã hủy xác thực.'), findsOneWidget);
  });

  testWidgets('does not overflow on narrow and wide layouts', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in [
      (
        size: const Size(320, 700),
        brightness: Brightness.light,
        textScaler: const TextScaler.linear(1.5),
      ),
      (
        size: const Size(900, 900),
        brightness: Brightness.dark,
        textScaler: TextScaler.noScaling,
      ),
    ]) {
      tester.view.physicalSize = configuration.size;
      await _pumpScreen(
        tester,
        _FakeAuthenticator(
          capabilityValue: const BiometricCapability(
            isAvailable: true,
            kind: BiometricKind.face,
          ),
        ),
        brightness: configuration.brightness,
        textScaler: configuration.textScaler,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
