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
  static const browseSessions = '/sessions';
  static String sessionDetail(String id) => '/sessions/$id';
  static String liveSession(String id) => '/sessions/$id/live';
  static String manageSession(String id) => '/sessions/$id/manage';
  static String editSession(String id) => '/sessions/$id/edit';
  static String cloneSession(String id) => '/sessions/$id/clone';
  static String rateSession(String id) => '/sessions/$id/rate';

  static const createSession = '/sessions/create';

  static const join = '/join';
  static const scanQr = '/join/scan';

  static const notifications = '/notifications';
  static const transactions = '/transactions';
  static const profile = '/profile';
  static const feed = '/feed';
  static String socialPost(String id) => '/feed/$id';
  static String socialClub(String id) => '/feed/clubs/$id';
  static const manageClubs = '/feed/manage';
  static const createClub = '/feed/manage/create';
  static String manageClub(String id) => '/feed/manage/$id';
  static String editClub(String id) => '/feed/manage/$id/edit';
  static String publicProfile(String id) => '/user/$id';

  /// Bottom-nav destinations, in tab order. The shell's branch order must
  /// match this list — index is how go_router identifies a branch.
  static const shellDestinations = <String>[
    home,
    browseSessions,
    feed,
    profile,
  ];

  /// Route names, for `context.goNamed`. Names survive path refactors;
  /// prefer them over raw paths at call sites.
  static const nameSplash = 'splash';
  static const nameSignIn = 'signIn';
  static const nameSignUp = 'signUp';
  static const nameHome = 'home';
  static const nameSessionDetail = 'sessionDetail';
  static const nameLiveSession = 'liveSession';

  /// Routes reachable without an account.
  ///
  /// App Store guideline 5.1.1(i) forbids gating browsing behind
  /// registration, so browse and join must stay on this list.
  /// [splash] is deliberately absent: it is matched exactly by [isPublic], not
  /// by prefix — `'/'` is a prefix of every path.
  static const publicPaths = <String>[
    signIn,
    signUp,
    forgotPassword,
    resetPassword,
    browseSessions,
    join,
    scanQr,
  ];

  /// Routes that sit *under* a public path but still need an account.
  ///
  /// `/sessions` is public so anyone can browse, and [isPublic] matches by
  /// prefix — which would otherwise make `/sessions/create` public too and
  /// hand a signed-out user a form whose submit can only ever 401.
  /// Checked before [publicPaths]; the more specific rule wins.
  static const protectedPaths = <String>[createSession, manageClubs];

  /// A prefix match only counts on a segment boundary, so `/sessions` does not
  /// make `/sessionsecret` public.
  static bool isPublic(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    if (path == splash) return true;
    if (RegExp(r'^/user/[^/]+(?:/|$)').hasMatch(path)) return true;
    if (RegExp(
      r'^/sessions/[^/]+/(manage|edit|clone|rate)(?:/|$)',
    ).hasMatch(path)) {
      return false;
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
