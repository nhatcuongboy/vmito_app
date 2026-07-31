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
      expect(AppRoutes.isPublic(AppRoutes.publicProfile('u1')), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.signUp), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.forgotPassword), isTrue);
      expect(AppRoutes.isPublic(AppRoutes.resetPassword), isTrue);
      expect(
        AppRoutes.isPublic('${AppRoutes.resetPassword}?token=abc'),
        isTrue,
      );
    });

    test('home requires a session', () {
      // Regression: splash is '/', so a naive startsWith made every route
      // public and the auth gate never fired.
      expect(AppRoutes.isPublic(AppRoutes.home), isFalse);
      expect(AppRoutes.isPublic('/profile'), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.feed), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClubs), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.createClub), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClub('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.editClub('c1')), isFalse);
    });

    test('a protected route under a public one stays protected', () {
      // /sessions is public and isPublic matches by prefix, so without the
      // explicit protected list /sessions/create would open signed-out and its
      // submit could only ever 401.
      expect(AppRoutes.isPublic(AppRoutes.createSession), isFalse);
      expect(AppRoutes.isPublic('/sessions/create/anything'), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.editSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.cloneSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.rateSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.transactions), isFalse);

      // The sibling detail route is still public.
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
    });

    test('only matches on a segment boundary', () {
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessionsecret'), isFalse);
    });
  });
}
