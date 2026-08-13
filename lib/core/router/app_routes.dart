/// Every route path and name in one place.
///
/// Unlike the web app there is **no `[locale]` prefix**: the locale is app
/// state, not part of the URL. Deep links from vmito.com therefore arrive with
/// a locale segment that the redirect handler strips — see [stripLocale].
abstract final class AppRoutes {
  static const splash = '/';

  static const signIn = '/auth/sign-in';
  static const signUp = '/auth/sign-up';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';

  static const home = '/home';
  static const leaderboard = '/leaderboard';
  static const homeDiscoveryTabQuery = 'tab';
  static String homeForVenue(String venueId, String venueName) => Uri(
    path: home,
    queryParameters: {'venueId': venueId, 'venueName': venueName},
  ).toString();
  static String homeForDiscoveryTab(String tab) => Uri(
    path: home,
    queryParameters: {homeDiscoveryTabQuery: tab},
  ).toString();
  static const browseSessions = '/sessions';
  static const pendingRequests = '/sessions/pending-requests';
  static String sessionDetail(String id) => '/sessions/$id';
  static String liveSession(String id) => '/sessions/$id/live';
  static String manageSession(String id) => '/sessions/$id/manage';
  static String editSession(String id) => '/sessions/$id/edit';
  static String cloneSession(String id) => '/sessions/$id/clone';
  static String rateSession(String id) => '/sessions/$id/rate';

  static const createSession = '/sessions/create';

  static const join = '/join';
  static const scanQr = '/join/scan';

  static const notifications = '$home/notifications';
  static const favorites = '/favorites';
  static const transactions = '/transactions';
  static const profile = '/profile';
  static const settings = '/settings';
  static const accountSecurity = '/settings/account-security';
  static const feed = '/feed';
  static const venues = '/venues';
  static String venueDetail(String id) => '/venues/$id';
  static const clubs = '/clubs';
  static String clubDetail(String id) => '/clubs/$id';
  static String socialPost(String id) => '/feed/$id';
  static String socialClub(String id) => '/feed/clubs/$id';
  static const manageClubs = '/feed/manage';
  static const createClub = '/feed/manage/create';
  static String manageClub(String id) => '/feed/manage/$id';
  static String editClub(String id) => '/feed/manage/$id/edit';
  static String publicProfile(String id) => '/user/$id';

  static const tournaments = '/tournaments';
  static String tournamentDetail(String id) => '/tournaments/$id';
  static const createTournament = '/tournaments/create';

  /// Bottom-nav destinations, in tab order. The shell's branch order must
  /// match this list — index is how go_router identifies a branch.
  static const shellDestinations = <String>[
    home,
    browseSessions,
    feed,
    favorites,
    profile,
  ];

  /// Route names, for `context.goNamed`. Names survive path refactors;
  /// prefer them over raw paths at call sites.
  static const nameSplash = 'splash';
  static const nameSignIn = 'signIn';
  static const nameSignUp = 'signUp';
  static const nameHome = 'home';
  static const nameLeaderboard = 'leaderboard';
  static const nameProfile = 'profile';
  static const nameSettings = 'settings';
  static const nameAccountSecurity = 'accountSecurity';
  static const nameSessionDetail = 'sessionDetail';
  static const nameLiveSession = 'liveSession';
  static const namePublicProfile = 'publicProfile';

  /// Routes reachable without an account.
  ///
  /// App Store guideline 5.1.1(i) forbids gating discovery behind
  /// registration, so Home and public entity pages stay on this list.
  /// [splash] is deliberately absent: it is matched exactly by [isPublic], not
  /// by prefix — `'/'` is a prefix of every path.
  static const publicPaths = <String>[
    signIn,
    signUp,
    forgotPassword,
    resetPassword,
    home,
    leaderboard,
    venues,
    clubs,
    join,
    scanQr,
  ];

  /// Routes that sit *under* a public path but still need an account.
  ///
  static const protectedPaths = <String>[
    browseSessions,
    createSession,
    pendingRequests,
    notifications,
    manageClubs,
    createTournament,
  ];

  /// A prefix match only counts on a segment boundary, so `/sessions` does not
  /// make `/sessionsecret` public.
  static bool isPublic(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == splash) return true;
    if (RegExp(r'^/user/[^/]+(?:/|$)').hasMatch(path)) return true;
    final publicSession = RegExp(
      r'^/sessions/([^/]+)(?:/(live))?$',
    ).firstMatch(path);
    if (publicSession != null &&
        publicSession.group(1) != 'create' &&
        publicSession.group(1) != 'pending-requests') {
      return true;
    }
    if (protectedPaths.any(
      (protectedPath) =>
          path == protectedPath || path.startsWith('$protectedPath/'),
    )) {
      return false;
    }
    return publicPaths.any(
      (publicPath) => path == publicPath || path.startsWith('$publicPath/'),
    );
  }

  /// Removes a leading `/vi`, `/en` or `/cn` from an incoming universal link
  /// so web URLs resolve against these paths.
  static String stripLocale(String location) {
    final match = RegExp(r'^/(vi|en|cn)(/|$)').firstMatch(location);
    if (match == null) return location;
    final rest = location.substring(
      match.end - (match.group(2) == '/' ? 1 : 0),
    );
    return rest.isEmpty ? '/' : rest;
  }
}
