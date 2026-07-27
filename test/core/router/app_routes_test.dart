import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/router/app_routes.dart';

void main() {
  group('stripLocale', () {
    test('removes a locale prefix from a web deep link', () {
      expect(AppRoutes.stripLocale('/vi/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/en/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/cn/sessions/abc'), '/sessions/abc');
    });

    test('maps a bare locale root to /', () {
      expect(AppRoutes.stripLocale('/vi'), '/');
      expect(AppRoutes.stripLocale('/vi/'), '/');
    });

    test('leaves a path without a locale alone', () {
      expect(AppRoutes.stripLocale('/sessions/abc'), '/sessions/abc');
    });

    test('does not strip a segment that merely starts with a locale code', () {
      expect(AppRoutes.stripLocale('/venues/abc'), '/venues/abc');
      expect(AppRoutes.stripLocale('/england'), '/england');
    });
  });

  group('isPublic', () {
    test('browse and join are reachable without an account', () {
      // App Store guideline 5.1.1(i): browsing must not require registration.
      expect(AppRoutes.isPublic(AppRoutes.browseSessions), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.join), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.scanQr), isTrue);
    });

    test('home requires a session', () {
      // Regression: splash is '/', so a naive startsWith made every route
      // public and the auth gate never fired.
      expect(AppRoutes.isPublic(AppRoutes.home), isFalse);
      expect(AppRoutes.isPublic('/profile'), isFalse);
    });

    test('only matches on a segment boundary', () {
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessionsecret'), isFalse);
    });
  });
}
