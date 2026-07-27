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

  static const home = '/home';
  static const browseSessions = '/sessions';
  static String sessionDetail(String id) => '/sessions/$id';

  static const join = '/join';
  static const scanQr = '/join/scan';

  static const notifications = '/notifications';
  static const profile = '/profile';

  /// Route names, for `context.goNamed`. Names survive path refactors;
  /// prefer them over raw paths at call sites.
  static const nameSplash = 'splash';
  static const nameSignIn = 'signIn';
  static const nameSignUp = 'signUp';
  static const nameHome = 'home';
  static const nameSessionDetail = 'sessionDetail';

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
    browseSessions,
    join,
    scanQr,
  ];

  /// A prefix match only counts on a segment boundary, so `/sessions` does not
  /// make `/sessionsecret` public.
  static bool isPublic(String location) {
    if (location == splash) return true;
    return publicPaths.any(
      (path) => location == path || location.startsWith('$path/'),
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
