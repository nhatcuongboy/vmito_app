import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/router/app_routes.dart';

void main() {
  group('stripLocale', () {
    test('removes a locale prefix from a web deep link', () {
      expect(AppRoutes.stripLocale('/vi/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/en/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/cn/sessions/abc'), '/sessions/abc');
      expect(AppRoutes.stripLocale('/vi/leaderboard'), '/leaderboard');
      expect(
        AppRoutes.stripLocale('/vi/tournament/vmito-open'),
        '/tournaments/vmito-open',
      );
      expect(
        AppRoutes.stripLocale('/vi/tournament/vmito-open/manage'),
        '/tournaments/vmito-open/manage',
      );
      expect(
        AppRoutes.stripLocale('/vi/host/tournaments'),
        AppRoutes.hostTournaments,
      );
    });

    test('maps a bare locale root to /', () {
      expect(AppRoutes.stripLocale('/vi'), '/');
      expect(AppRoutes.stripLocale('/vi/'), '/');
    });

    test('leaves a path without a locale alone', () {
      expect(AppRoutes.stripLocale('/sessions/abc'), '/sessions/abc');
      expect(
        AppRoutes.stripLocale('/tournament/vmito-open'),
        '/tournaments/vmito-open',
      );
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
        expect(AppRoutes.isPublic(AppRoutes.liveSession('s1')), isFalse);
        expect(AppRoutes.isPublic(AppRoutes.join), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.scanQr), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.publicProfile('u1')), isTrue);
        expect(AppRoutes.isPublic(AppRoutes.tournamentDetail('t1')), isTrue);
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
      expect(AppRoutes.isPublic(AppRoutes.editProfile), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.changePassword), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.feed), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClubs), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.createClub), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.manageClub('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.editClub('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.clubFees('c1')), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.hostTournaments), isFalse);
      expect(AppRoutes.isPublic(AppRoutes.roster), isFalse);
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
      expect(
        AppRoutes.isPublic(AppRoutes.manageTournament('vmito-open')),
        isFalse,
      );
      expect(AppRoutes.isPublic(AppRoutes.feedback), isFalse);
      expect(
        AppRoutes.isPublic(AppRoutes.mySessionsSearchFor('hosted')),
        isFalse,
      );

      // The sibling detail route is still public.
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessions/abc/live'), isFalse);
    });

    test('only matches on a segment boundary', () {
      expect(AppRoutes.isPublic('/sessions/abc'), isTrue);
      expect(AppRoutes.isPublic('/sessionsecret'), isFalse);
    });
  });

  group('isFeedLocation', () {
    test('recognizes the feed root and a post detail', () {
      expect(AppRoutes.isFeedLocation(AppRoutes.feed), isTrue);
      expect(AppRoutes.isFeedLocation(AppRoutes.socialPost('post-1')), isTrue);
    });

    test('excludes management and unrelated routes', () {
      expect(AppRoutes.isFeedLocation(AppRoutes.manageClubs), isFalse);
      expect(AppRoutes.isFeedLocation(AppRoutes.manageClub('club-1')), isFalse);
      expect(AppRoutes.isFeedLocation('/feed/clubs/club-1'), isFalse);
      expect(AppRoutes.isFeedLocation(AppRoutes.home), isFalse);
    });
  });

  test('favorites replaces notifications as the fourth shell destination', () {
    expect(AppRoutes.shellDestinations[3], AppRoutes.favorites);
    expect(
      AppRoutes.shellDestinations,
      isNot(contains(AppRoutes.notifications)),
    );
  });

  test('favoritesFor selects the requested API type', () {
    expect(AppRoutes.favoritesFor('CLUB'), '/favorites?type=CLUB');
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
    expect(
      AppRoutes.hidesBottomNavigation(AppRoutes.liveSession('s1')),
      isTrue,
    );
    expect(
      AppRoutes.hidesBottomNavigation(AppRoutes.manageTournament('t1')),
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

  test('mySessionsSearchFor builds correct path and query parameters', () {
    final uri = Uri.parse(
      AppRoutes.mySessionsSearchFor('hosted', query: 'court 1'),
    );

    expect(uri.path, AppRoutes.mySessionsSearch);
    expect(uri.queryParameters['scope'], 'hosted');
    expect(uri.queryParameters['q'], 'court 1');
  });

  test('manageClubsForTab encodes a stable tab query', () {
    final uri = Uri.parse(AppRoutes.manageClubsForTab('member'));

    expect(uri.path, AppRoutes.manageClubs);
    expect(uri.queryParameters[AppRoutes.clubManagementTabQuery], 'member');
  });

  test('notification approval destinations encode their initial tabs', () {
    final session = Uri.parse(AppRoutes.manageSession('s1', tab: 'roster'));
    final club = Uri.parse(AppRoutes.manageClub('c1', tab: 'requests'));

    expect(session.path, '/sessions/s1/manage');
    expect(session.queryParameters['tab'], 'roster');
    expect(club.path, '/feed/manage/c1');
    expect(club.queryParameters['tab'], 'requests');
  });

  test('signInWithRedirect preserves the post-login destination', () {
    final uri = Uri.parse(
      AppRoutes.signInWithRedirect(AppRoutes.createSession),
    );

    expect(uri.path, AppRoutes.signIn);
    expect(uri.queryParameters['redirect'], AppRoutes.createSession);
  });

  test('manageTournament and web normalization retain compatible query', () {
    final route = Uri.parse(
      AppRoutes.manageTournament(
        'vmito open',
        option: 'registration',
        categoryId: 'cat 1',
      ),
    );
    final normalized = Uri.parse(
      AppRoutes.normalizeWebLocation(
        Uri.parse(
          '/vi/tournament/vmito-open/manage?option=location&categoryId=c1',
        ),
      ),
    );

    expect(route.path, '/tournaments/vmito%20open/manage');
    expect(route.queryParameters['option'], 'registration');
    expect(route.queryParameters['categoryId'], 'cat 1');
    expect(normalized.path, '/tournaments/vmito-open/manage');
    expect(normalized.queryParameters, {
      'option': 'location',
      'categoryId': 'c1',
    });
    expect(
      AppRoutes.normalizeWebLocation(
        Uri.parse('/tournaments/vmito%20open/manage?option=contact'),
      ),
      '/tournaments/vmito%20open/manage?option=contact',
    );
    expect(
      AppRoutes.normalizeWebLocation(
        Uri.parse(
          'https://vmito.com/en/tournament/open/manage?option=results',
        ),
      ),
      '/tournaments/open/manage?option=results',
    );
  });
}
