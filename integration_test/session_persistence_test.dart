import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

/// Does a signed-in session survive an app restart?
///
/// This runs on a device against the **real Keychain/Keystore**, which is the
/// only place the answer is decidable — a VM test would be exercising a fake.
///
/// A fresh [TokenStorage] instance stands in for a relaunch: `bootstrap()`
/// constructs one and calls `hydrate()` before the first frame, so if a new
/// instance can read what a previous one wrote, the session persists.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    // Keychain items outlive app deletion, so a leaked token would follow this
    // simulator into later runs.
    await TokenStorage().clear();
  });

  testWidgets('tokens written at sign-in survive a relaunch', (tester) async {
    await TokenStorage().save(
      accessToken: 'access-token-value',
      refreshToken: 'refresh-token-value',
    );

    // The relaunch.
    final afterRestart = TokenStorage();
    expect(
      afterRestart.hasAccessToken,
      isFalse,
      reason: 'must be empty until hydrate() runs — bootstrap awaits it',
    );

    await afterRestart.hydrate();

    expect(afterRestart.hasAccessToken, isTrue);
    expect(afterRestart.accessToken, 'access-token-value');
    expect(await afterRestart.readRefreshToken(), 'refresh-token-value');
  });

  testWidgets('sign-out clears both tokens for good', (tester) async {
    final storage = TokenStorage();
    await storage.save(accessToken: 'a', refreshToken: 'r');
    await storage.clear();

    final afterRestart = TokenStorage();
    await afterRestart.hydrate();

    expect(afterRestart.hasAccessToken, isFalse);
    expect(await afterRestart.readRefreshToken(), isNull);
  });

  testWidgets('a refresh keeps the refresh token when none is returned', (
    tester,
  ) async {
    // `/auth/refresh` may return only a new access token. Dropping the refresh
    // token there would sign the user out at the next expiry.
    final storage = TokenStorage();
    await storage.save(accessToken: 'old', refreshToken: 'keep-me');

    await storage.updateAccessToken('new');

    final afterRestart = TokenStorage();
    await afterRestart.hydrate();

    expect(afterRestart.accessToken, 'new');
    expect(await afterRestart.readRefreshToken(), 'keep-me');
  });
}
