@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/auth/data/auth_service.dart';

import '../support/fake_secure_storage.dart';

/// Exercises the real network stack against a running `vmito-be`.
///
/// This is the only test that proves dio, the interceptors and the error
/// mapping agree with what the backend actually sends — unit tests assert
/// against captured payloads, which can go stale.
///
/// Skipped automatically when the backend is not reachable, so it never breaks
/// a normal `flutter test` run. To run it deliberately:
///
/// ```sh
/// cd ../vmito-be && npm run start:dev     # must be up
/// flutter test test/integration/
/// ```
///
/// It only calls endpoints that are safe to hit repeatedly: no account is
/// created, nothing is mutated. `/auth/login` is rate-limited to 5 requests
/// per minute, so keep the login assertions few.
Future<void> main() async {
  // Probed before the group is declared so `skip` can be set from it.
  final backendIsUp = await _probeBackend();

  group('live backend', _defineTests, skip: backendIsUp ? null : _skipReason);
}

const _skipReason =
    'vmito-be is not listening on localhost:3001 — start it to run these.';

Future<bool> _probeBackend() async {
  try {
    final socket = await Socket.connect(
      'localhost',
      3001,
      timeout: const Duration(milliseconds: 500),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}

void _defineTests() {
  late ApiClient client;
  late AuthService auth;

  setUpAll(() async {
    // No TestWidgetsFlutterBinding here on purpose: initialising it makes every
    // HTTP request return 400 without touching the network, which defeats the
    // point of this file. That also rules out mocking the Keychain method
    // channel, so TokenStorage gets an in-memory fake instead — a 401 on a
    // protected endpoint reads the refresh token, and an unmocked channel call
    // hangs until the 30s test timeout rather than failing.
    client = buildApiClient(
      tokenStorage: TokenStorage(FakeSecureStorage()),
      errorBus: ApiErrorBus(),
      onSessionExpired: () async {},
    );
    auth = AuthService(client);
  });

  test('backend is reachable at the configured base URL', () async {
    expect(AppConfig.apiBaseUrl, contains('/api'));
  });

  test('rejected credentials surface the backend message verbatim', () async {
    await expectLater(
      auth.login(email: 'definitely-not-a-user@example.com', password: 'nope'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized)
            // The whole point: a real message, not a generic fallback.
            .having((e) => e.message, 'message', 'Invalid credentials'),
      ),
    );
  });

  test('validation failures list every offending field', () async {
    await expectLater(
      auth.login(email: '', password: ''),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.message, 'message', contains('email')),
      ),
    );
  });

  test('a protected endpoint 401s for an anonymous client', () async {
    await expectLater(
      auth.currentUser(),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)),
    );
  });
}
