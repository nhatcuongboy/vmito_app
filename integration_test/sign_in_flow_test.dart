import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vmito_app/app.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';

/// Drives the real app on a real device against a running `vmito-be`.
///
/// This is the only check that covers the parts a VM test cannot: App Transport
/// Security, the Keychain, and the widget tree wired to the live API.
///
/// ```sh
/// cd ../vmito-be && npm run start:dev
/// flutter test integration_test/ -d <device-id> \
///     --dart-define-from-file=env/dev.json
/// ```
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rejected sign-in shows the message the backend sent', (
    tester,
  ) async {
    final tokens = TokenStorage();
    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(
          buildApiClient(
            tokenStorage: tokens,
            errorBus: ApiErrorBus(),
            onSessionExpired: () async {},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VmitoApp()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byType(TextFormField),
      findsNWidgets(2),
      reason: 'no stored token, so the router should land on sign-in',
    );

    await tester.enterText(
      find.byType(TextFormField).first,
      'definitely-not-a-user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');

    await tester.tap(find.byType(FilledButton));
    // A real network round trip: pumpAndSettle alone can finish before it lands.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // Reaching this text proves the whole chain worked on-device: ATS allowed
    // the request, dio sent it, the backend replied 401, and the nested
    // `error.message` was unwrapped. A network-layer failure would surface a
    // generic message instead.
    expect(find.text('Invalid credentials'), findsOneWidget);
  });

  testWidgets('the keyboard "done" action cannot double-submit', (
    tester,
  ) async {
    final tokens = TokenStorage();
    var loginAttempts = 0;

    final client = buildApiClient(
      tokenStorage: tokens,
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    client.raw.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('/auth/login')) loginAttempts++;
          handler.next(options);
        },
      ),
    );

    final container = ProviderContainer(
      overrides: [
        tokenStorageProvider.overrideWithValue(tokens),
        apiClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).restoreSession();

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VmitoApp()),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'a@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'wrong-password');

    // Tap and "done" in the same frame — what a fast user actually does.
    await tester.tap(find.byType(FilledButton));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // Regression: onFieldSubmitted had no _isSubmitting guard, so this sent
    // two logins. /auth/login allows only 5 per minute.
    expect(loginAttempts, 1);
  });
}
