import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/config/app_config.dart';

void main() {
  group('AppConfig auth bypass', () {
    test('allows an explicitly requested bypass only in development', () {
      expect(
        AppConfig.isAuthBypassAllowed(
          flavor: AppFlavor.dev,
          requested: true,
        ),
        isTrue,
      );
    });

    test('rejects a bypass when it was not explicitly requested', () {
      expect(
        AppConfig.isAuthBypassAllowed(
          flavor: AppFlavor.dev,
          requested: false,
        ),
        isFalse,
      );
    });

    test('rejects a requested bypass outside development', () {
      for (final flavor in [AppFlavor.staging, AppFlavor.production]) {
        expect(
          AppConfig.isAuthBypassAllowed(flavor: flavor, requested: true),
          isFalse,
        );
      }
    });
  });
}
