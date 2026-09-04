import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/security/app_lock_controller.dart';
import 'package:vmito_app/core/security/biometric_authenticator.dart';
import 'package:vmito_app/core/security/biometric_lock_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/profile/presentation/account_security_screen.dart';
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

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: const AccountSecurityScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
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
