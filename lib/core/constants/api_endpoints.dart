/// Backend paths, relative to `AppConfig.apiBaseUrl`.
///
/// Only the endpoints the app already calls belong here — add a group when you
/// port the matching service from `vmito-fe/src/lib/api/`. Never inline a path
/// string at a call site.
abstract final class ApiEndpoints {
  // --- Auth -----------------------------------------------------------------
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const refresh = '/auth/refresh';
  static const changePassword = '/auth/change-password';
  static const forgotPassword = '/auth/forgot-password';
  static const resetPassword = '/auth/reset-password';
  static const verifyResetToken = '/auth/verify-reset-token';

  /// Backend-driven OAuth. The app opens these in a web auth session; the
  /// backend redirects back with tokens as **query parameters** — there is no
  /// code exchange on the client.
  static const oauthGoogle = '/auth/google';
  static const oauthFacebook = '/auth/facebook';

  // --- Users ----------------------------------------------------------------
  static const currentUser = '/users/me';
  static String user(String id) => '/users/$id';

  // --- Players / join flow --------------------------------------------------
  static const checkCode = '/players/check-code';
  static const joinByCode = '/players/join-by-code';

  // --- Sessions -------------------------------------------------------------
  static const sessions = '/sessions';
  static String session(String id) => '/sessions/$id';
  static String sessionPlayers(String id) => '/sessions/$id/players';

  // --- Courts ---------------------------------------------------------------
  static String court(String id) => '/courts/$id';

  /// Server-side matchmaking. The app renders what this returns and never
  /// computes suggestions locally.
  /// Query: `topCount`, `useAi`, `language`, `matchType`.
  static String suggestedPlayers(String courtId) =>
      '/courts/$courtId/suggested-players';

  // --- Notifications --------------------------------------------------------
  static const notifications = '/notifications';

  /// Not implemented on the backend yet — P0 task, see docs/ROADMAP.md.
  static const notificationDevices = '/notifications/devices';
}
