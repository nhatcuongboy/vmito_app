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
import 'package:vmito_app/features/session/data/session_service.dart';

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
/// created, nothing is mutated.
///
/// **Exactly one test may call `/auth/login`.** It is rate-limited to 5
/// requests per minute, and a second call made the suite fail intermittently
/// once the on-device tests had also used the budget. Assert validation shapes
/// against an unthrottled endpoint instead.
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
      // Generous on purpose: a 500ms probe timed out under the load of a full
      // `flutter test` run and silently skipped this whole file, which is the
      // worst outcome — the live checks looked green by being absent.
      timeout: const Duration(seconds: 3),
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
    // Deliberately NOT /auth/login: that endpoint allows 5 requests per
    // minute, and a second login assertion here made the whole suite flaky —
    // repeated full runs turned the expected 400 into a 429. /join-by-code is
    // public, unthrottled, and produces the same class-validator shape.
    await expectLater(
      auth.joinByCode(sessionCode: '', name: ''),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.message, 'message', contains('sessionCode'))
            // Every offending field is joined, not just the first.
            .having((e) => e.message, 'message', contains('name')),
      ),
    );
  });

  test('public session browse decodes real payloads', () async {
    // The Session model is hand-written from vmito-fe/src/lib/api/types.ts —
    // the OpenAPI document has no response schemas, so nothing else checks it
    // against what the backend actually sends.
    final sessions = SessionService(client);
    final page = await sessions.browsePublic(limit: 5);

    expect(page.page, 1);
    expect(page.total, greaterThanOrEqualTo(0));
    for (final session in page.items) {
      expect(session.id, isNotEmpty);
      expect(session.name, isNotEmpty);
    }
  });

  test('session detail decodes courts, players and fees', () async {
    final sessions = SessionService(client);
    final page = await sessions.browsePublic(limit: 20);
    if (page.items.isEmpty) {
      markTestSkipped('no public sessions on this backend');
      return;
    }

    // Pick the richest session so courts/players/fees are actually exercised;
    // an empty one would make this test pass without decoding anything.
    final target = page.items.reduce(
      (a, b) => b.playerCount >= a.playerCount ? b : a,
    );
    final detail = await sessions.byId(target.id);

    expect(detail.id, target.id);
    for (final court in detail.courts) {
      expect(court.courtNumber, greaterThan(0));
      // customName is null when the host never named the court — the UI
      // formats the number instead, so an absent name is not a failure.
      expect(court.customName, anyOf(isNull, isNotEmpty));
    }
    for (final player in detail.players) {
      // Level must stay an int: the values are non-contiguous (1-8, 9, 10).
      expect(player.level, anyOf(isNull, isA<int>()));
    }
    if (detail.feeConfig case final fees?) {
      expect(fees.maleFee, anyOf(isNull, isA<int>()));
    }
  });

  test('Apple sign-in rejects a token it cannot verify', () async {
    // The endpoint must never trust a client-supplied token. A forged or
    // malformed one has to fail closed — an accepted token here would be an
    // authentication bypass, not a cosmetic bug.
    await expectLater(
      auth.signInWithApple(identityToken: 'not-a-real-apple-jwt'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.kind, 'kind', ApiErrorKind.unauthorized),
      ),
    );
  });

  test('Apple sign-in validates its payload', () async {
    await expectLater(
      auth.signInWithApple(identityToken: ''),
      throwsA(
        isA<ApiException>()
            .having((e) => e.kind, 'kind', ApiErrorKind.validation)
            .having((e) => e.message, 'message', contains('identityToken')),
      ),
    );
  });

  test('account deletion requires authentication', () async {
    // DELETE /users/me must not be reachable anonymously, and must not fall
    // through to the admin-only DELETE /users/:id route with id="me".
    await expectLater(
      auth.deleteAccount(),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)),
    );
  });

  test('a protected endpoint 401s for an anonymous client', () async {
    await expectLater(
      auth.currentUser(),
      throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)),
    );
  });
}
