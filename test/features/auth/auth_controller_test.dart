import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

import '../../support/fake_secure_storage.dart';

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
}
