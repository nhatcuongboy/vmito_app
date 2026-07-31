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

  /// Native Sign in with Apple. Unlike Google/Facebook this is **not** a
  /// redirect: the client verifies with Apple on-device and posts the
  /// resulting identity token here.
  static const appleSignIn = '/auth/apple';

  // --- Users ----------------------------------------------------------------
  static const currentUser = '/users/me';

  /// In-app account deletion. Required by App Store guideline 5.1.1(v).
  static const deleteAccount = '/users/me';
  static String user(String id) => '/users/$id';
  static String publicUser(String id) => '/users/public/$id';

  // --- Social ---------------------------------------------------------------
  static const postsFeed = '/posts/feed';
  static const posts = '/posts';
  static String post(String id) => '/posts/$id';
  static String postLike(String id) => '/posts/$id/like';
  static String postComments(String id) => '/posts/$id/comments';
  static String postShare(String id) => '/posts/$id/share';
  static String userPosts(String userId) => '/posts/user/$userId';

  static const clubs = '/clubs';
  static String clubDetails(String id) => '/clubs/$id/details';
  static String clubJoin(String id) => '/clubs/$id/join';
  static String clubLeave(String id) => '/clubs/$id/leave';
  static const myClubs = '/clubs/my/list';
  static const managedClubs = '/clubs/manage';
  static const clubUserSearch = '/clubs/search-users';
  static String managedClub(String id) => '/clubs/$id';
  static String clubMembers(String id) => '/clubs/$id/members';
  static String clubMember(String clubId, String userId) =>
      '/clubs/$clubId/members/$userId';
  static String clubMemberRole(String clubId, String userId) =>
      '/clubs/$clubId/members/$userId/role';
  static String clubJoinRequests(String id) => '/clubs/$id/join-requests';
  static String clubJoinRequestApprove(String clubId, String requestId) =>
      '/clubs/$clubId/join-requests/$requestId/approve';
  static String clubJoinRequestReject(String clubId, String requestId) =>
      '/clubs/$clubId/join-requests/$requestId/reject';
  static String clubAnnouncements(String id) => '/clubs/$id/announcements';
  static String clubAnnouncement(String clubId, String announcementId) =>
      '/clubs/$clubId/announcements/$announcementId';
  static String userClubs(String userId) => '/clubs/user/$userId/list';

  static String userRatingStats(String userId) => '/ratings/user/$userId/stats';
  static String userReceivedRatings(String userId) =>
      '/ratings/user/$userId/received';
  static const ratings = '/ratings';
  static String sessionRatingEligibility(String sessionId) =>
      '/ratings/session/$sessionId/eligibility';

  // --- Players / join flow --------------------------------------------------
  static const checkCode = '/players/check-code';
  static const joinByCode = '/players/join-by-code';

  // --- Sessions -------------------------------------------------------------
  static const sessions = '/sessions';

  /// Public browse — no token required, and it must stay that way
  /// (App Store guideline 5.1.1(i)).
  static const publicSessions = '/sessions/public';
  static const availableSessions = '/sessions/available';

  /// Authenticated list. Filter by `hostId` for the caller's own sessions;
  /// `POST` to the same path creates one.
  static const mySessions = '/sessions';
  static String session(String id) => '/sessions/$id';
  static String sessionStart(String id) => '/sessions/$id/start';
  static String sessionEnd(String id) => '/sessions/$id/end';
  static String sessionCancel(String id) => '/sessions/$id/cancel';
  static String sessionPlayers(String id) => '/sessions/$id/players';
  static String sessionPlayer(String sessionId, String playerId) =>
      '/sessions/$sessionId/players/$playerId';
  static String sessionPlayerStatus(String sessionId, String playerId) =>
      '/sessions/$sessionId/players/$playerId/status';
  static String sessionPlayerToggleInactive(String sessionId) =>
      '/sessions/$sessionId/players/toggle-inactive';

  // --- Courts ---------------------------------------------------------------
  static String court(String id) => '/courts/$id';
  static String courtSelectPlayers(String id) => '/courts/$id/select-players';
  static String courtDeselectPlayers(String id) =>
      '/courts/$id/deselect-players';
  static String courtStartMatch(String id) => '/courts/$id/start-match';
  static String courtEndMatch(String id) => '/courts/$id/end-match';

  /// Server-side matchmaking. The app renders what this returns and never
  /// computes suggestions locally.
  /// Query: `topCount`, `useAi`, `language`, `matchType`.
  static String suggestedPlayers(String courtId) =>
      '/courts/$courtId/suggested-players';

  // --- Payments ------------------------------------------------------------
  static const paymentSettings = '/payment-settings';
  static String paymentSetting(String id) => '/payment-settings/$id';
  static String paymentSettingDefault(String id) =>
      '/payment-settings/$id/set-default';
  static String sessionPayments(String id) => '/sessions/$id/payments';
  static String paymentApprove(String id) => '/payments/$id/approve';
  static String paymentReject(String id) => '/payments/$id/reject';
  static const paymentBulkApprove = '/payments/bulk-approve';
  static const hostPaymentSummary = '/payments/host/summary';
  static String hostPaymentsForUser(String userId) =>
      '/payments/host/user/$userId';
  static String sessionPaymentSplit(String id) =>
      '/sessions/$id/payments/split';
  static String sessionExpenses(String id) => '/sessions/$id/expenses';
  static String sessionExpense(String sessionId, String expenseId) =>
      '/sessions/$sessionId/expenses/$expenseId';

  // --- Notifications --------------------------------------------------------
  static const notifications = '/notifications';
  static const notificationUnreadCount = '/notifications/unread-count';
  static const notificationReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';

  /// Not implemented on the backend yet — P0 task, see docs/ROADMAP.md.
  static const notificationDevices = '/notifications/devices';
}
