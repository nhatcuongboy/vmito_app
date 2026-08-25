import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/router/app_routes.dart';

void main() {
  group('stripLocale', () {
    test('removes a locale prefix from a web deep link', () {
      expect(AppRoutes.stripLocale('/vi/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/en/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/cn/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/vi/leaderboard'), '/leaderboard');
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
    test(
      'home, public details, live and join are reachable without account',
      () {
        // App Store guideline 5.1.1(i): browsing must not require registration.
        expect(AppRoutes.isPublic(AppRoutes.home), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.leaderboard), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.sessionDetail('s1')), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.liveSession('s1')), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.join), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.scanQr), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.publicProfile('u1')), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.signUp), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.forgotPassword), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.resetPassword), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.terms), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.privacy), isTrue);
        expect(
          AppRoutes.isPublic('${AppRoutes.resetPassword}?token=abc'),
          isTrue,
        );
      },
    );

    test('personal destinations require a session', () {
      // Regression: splash is '/', so a naive startsWith made every route
      // public and the auth gate never fired.
      expect(AppRoutes.isPublic(AppRoutes.browseSessions), isFalse);
      expect(AppRoutes.isPublic('/profile'), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.feed), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClubs), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.createClub), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClub('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.editClub('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.clubFees('c1')), isFalse);
    });

    test('a protected route under a public one stays protected', () {
      // Public detail/live are exact matches, so sibling actions stay gated.
      expect(AppRoutes.isPublic(AppRoutes.createSession), isFalse);
      expect(AppRoutes.isPublic('/sessions/create/anything'), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.editSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.cloneSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.rateSession('abc')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.transactions), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.feedback), isFalse);
      expect(
        AppRoutes.isPublic(AppRoutes.mySessionsSearchFor('hosted')),
        isFalse,
      );

      // The sibling detail route is still public.
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessions/abc/live'), isTrue);
    });

    test('only matches on a segment boundary', () {
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessionsecret'), isFalse);
    });
  });

  test('favorites replaces notifications as the fourth shell destination', () {
    expect(AppRoutes.shellDestinations[3], AppRoutes.favorites);
    expect(
      AppRoutes.shellDestinations,
      isNot(contains(AppRoutes.notifications)),
    );
  });

  test('full-screen workspaces hide the shell bottom navigation', () {
    expect(AppRoutes.hidesBottomNavigation(AppRoutes.homeSearch), isTrue);
    expect(
      AppRoutes.hidesBottomNavigation(AppRoutes.manageSession('s1')),
      isTrue,
    );
    expect(
      AppRoutes.hidesBottomNavigation(AppRoutes.sessionDetail('s1')),
      isTrue,
    );
    expect(AppRoutes.hidesBottomNavigation(AppRoutes.createSession), isFalse);
    expect(
      AppRoutes.hidesBottomNavigation(
        AppRoutes.mySessionsSearchFor('joined', query: 'kèo tối'),
      ),
      isTrue,
    );
    expect(
      AppRoutes.hidesBottomNavigation(AppRoutes.editSession('s1')),
      isFalse,
    );
    expect(
      AppRoutes.hidesBottomNavigation('/sessions/s1/manage/history'),
      isFalse,
    );
  });

  test('homeSearchFor encodes tab and existing query', () {
    final uri = Uri.parse(
      AppRoutes.homeSearchFor('clubs', query: 'Nhóm Quận 1'),
    );

    expect(uri.path, AppRoutes.homeSearch);
    expect(uri.queryParameters[AppRoutes.homeDiscoveryTabQuery], 'clubs');
    expect(uri.queryParameters['q'], 'Nhóm Quận 1');
  });

  test('manageClubsForTab encodes a stable tab query', () {
    final uri = Uri.parse(AppRoutes.manageClubsForTab('member'));

    expect(uri.path, AppRoutes.manageClubs);
    expect(uri.queryParameters[AppRoutes.clubManagementTabQuery], 'member');
  });

  test('signInWithRedirect preserves the post-login destination', () {
    final uri = Uri.parse(
      AppRoutes.signInWithRedirect(AppRoutes.createSession),
    );

    expect(uri.path, AppRoutes.signIn);
    expect(uri.queryParameters['redirect'], AppRoutes.createSession);
  });
}
