import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  group('TokenStorage', () {
    test('hydrates the saved token pair in a new app process', () async {
      final secureStorage = FakeSecureStorage();
      await TokenStorage(
        secureStorage,
      ).save(accessToken: 'access', refreshToken: 'refresh');

      // A fresh TokenStorage instance represents a new Flutter process after
      // the user removes the app from Android/iOS recent apps.
      final restartedStorage = TokenStorage(secureStorage);
      expect(restartedStorage.hasPersistedSession, isFalse);

      await restartedStorage.hydrate();

      expect(restartedStorage.accessToken, 'access');
      expect(await restartedStorage.readRefreshToken(), 'refresh');
      expect(restartedStorage.hasPersistedSession, isTrue);
    });

    test('recognizes a refresh-only persisted session', () async {
      final secureStorage = FakeSecureStorage({
        'vmito.refresh_token': 'refresh',
      });
      final restartedStorage = TokenStorage(secureStorage);

      await restartedStorage.hydrate();

      expect(restartedStorage.hasAccessToken, isFalse);
      expect(restartedStorage.hasRefreshToken, isTrue);
      expect(restartedStorage.hasPersistedSession, isTrue);
    });
  });
}
