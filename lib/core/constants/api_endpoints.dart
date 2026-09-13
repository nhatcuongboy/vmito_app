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
  static const webViewSessions = '/auth/webview-sessions';
  static const webViewSessionExchange = '/auth/webview-sessions/exchange';
  static String revokeWebViewSession(String id) =>
      '/auth/webview-sessions/$id/revoke';

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
  static const users = '/users';
  static const unreadFeedCount = '/users/unread-feed-count';
  static const markFeedAsRead = '/users/mark-feed-as-read';

  /// In-app account deletion. Required by App Store guideline 5.1.1(v).
  static const deleteAccount = '/users/me';
  static String user(String id) => '/users/$id';

  static String publicUser(String id) => '/users/public/$id';
  static const uploadAvatar = '/upload/avatar';
  static const uploadCover = '/upload/cover';

  // --- Social ---------------------------------------------------------------
  static const postsFeed = '/posts/feed';
  static const posts = '/posts';
  static String post(String id) => '/posts/$id';
  static String postReport(String id) => '/posts/$id/report';
  static String postLike(String id) => '/posts/$id/like';
  static String postComments(String id) => '/posts/$id/comments';
  static String postShare(String id) => '/posts/$id/share';
  static String userPosts(String userId) => '/posts/user/$userId';
  static const leaderboard = '/leaderboard';
  static const leaderboardMe = '/leaderboard/me';
  static String userAchievements(String userId) =>
      '/leaderboard/users/$userId/achievements';

  static const clubs = '/clubs';
  static String clubDetails(String id) => '/clubs/$id/details';
  static String clubJoin(String id) => '/clubs/$id/join';
  static String clubLeave(String id) => '/clubs/$id/leave';
  static const myClubs = '/clubs/my/list';
  static const myClubRequests = '/clubs/my/requests';
  static const managedClubJoinRequests = '/clubs/my/join-requests';
  static const adminClubJoinRequests = '/clubs/admin/join-requests';
  static const pendingClubs = '/clubs/admin/pending';
  static const managedClubs = '/clubs/manage';
  static const clubUserSearch = '/clubs/search-users';
  static String clubFeeForMonth(String clubId, int year, int month) =>
      '/clubs/$clubId/fees/$year/$month';
  static String clubFees(String clubId) => '/clubs/$clubId/fees';
  static String clubMonthlyMembers(String clubId, int year, int month) =>
      '/clubs/$clubId/monthly-members/$year/$month';
  static String clubMonthlyMember(String clubId) =>
      '/clubs/$clubId/monthly-members';
  static String deleteClubMonthlyMember(
    String clubId,
    String userId,
    int year,
    int month,
  ) => '/clubs/$clubId/monthly-members/$userId/$year/$month';
  static String managedClub(String id) => '/clubs/$id';
  static String cancelClubJoinRequest(String id) => '/clubs/$id/join-request';
  static String approveClub(String id) => '/clubs/$id/approve';
  static String rejectClub(String id) => '/clubs/$id/reject';
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
  static const userRatingBatchStats = '/ratings/users/batch-stats';
  static String userReceivedRatings(String userId) =>
      '/ratings/user/$userId/received';
  static const ratings = '/ratings';
  static String sessionRatingEligibility(String sessionId) =>
      '/ratings/session/$sessionId/eligibility';

  // --- Players / join flow --------------------------------------------------
  static const checkCode = '/players/check-code';
  static const joinByCode = '/players/join-by-code';

  /// One registration row. `DELETE` here is how a player withdraws — the
  /// backend has no dedicated withdraw endpoint.
  static String player(String id) => '/players/$id';
  static const joinedSessions = '/players/me/sessions';
  static const myJoinRequests = '/players/me/join-requests';
  static String withdrawMyJoinRequest(String sessionId) =>
      '/players/me/join-requests/$sessionId';
  static const pendingJoinRequests = '/players/pending-requests';
  static const pendingJoinRequestCount = '/players/pending-requests/count';
  static const pendingJoinRequestsBatch = '/players/pending-requests/batch';

  // --- Sessions -------------------------------------------------------------
  static const sessions = '/sessions';

  /// Public browse — no token required, and it must stay that way
  /// (App Store guideline 5.1.1(i)).
  static const publicSessions = '/sessions/public';
  static const availableSessions = '/sessions/available';

  /// Authenticated list. Filter by `hostId` for the caller's own sessions;
  /// `POST` to the same path creates one.
  static const mySessions = '/sessions';

  /// Clones one draft across several dates in a single call. Body carries the
  /// whole `baseSession` plus either `specificDates` or `recurringWeekdays`.
  static const sessionsBulk = '/sessions/bulk';
  static String session(String id) => '/sessions/$id';
  static String sessionRecommendations(String id) =>
      '/sessions/$id/recommendations';
  static String sessionStart(String id) => '/sessions/$id/start';
  static String sessionEnd(String id) => '/sessions/$id/end';
  static String sessionCancel(String id) => '/sessions/$id/cancel';
  static String sessionPlayers(String id) => '/sessions/$id/players';
  static String sessionPlayersBulk(String id) => '/sessions/$id/players/bulk';
  static String sessionPlayerStatistics(String id) =>
      '/sessions/$id/players/statistics';

  /// Self-service registration. Body is wrapped: `{"players": [...]}`.
  static String sessionRegister(String id) => '/sessions/$id/players/register';

  /// The caller's own rows for a session, plus any guests they registered.
  static String sessionMyPlayers(String id) => '/sessions/$id/players/me';
  static String sessionPlayer(String sessionId, String playerId) =>
      '/sessions/$sessionId/players/$playerId';
  static String sessionPlayerStatus(String sessionId, String playerId) =>
      '/sessions/$sessionId/players/$playerId/status';
  static String sessionPlayerToggleInactive(String sessionId) =>
      '/sessions/$sessionId/players/toggle-inactive';

  /// Finished matches for a session. Feeds the repeat-pairing warning.
  static String sessionMatches(String id) => '/sessions/$id/matches';

  /// Read or mutate one completed match.
  static String match(String id) => '/matches/$id';

  // --- Courts ---------------------------------------------------------------
  static String court(String id) => '/courts/$id';
  static String courtSelectPlayers(String id) => '/courts/$id/select-players';
  static String courtDeselectPlayers(String id) =>
      '/courts/$id/deselect-players';
  static String courtStartMatch(String id) => '/courts/$id/start-match';
  static String courtEndMatch(String id) => '/courts/$id/end-match';
  static String courtCurrentMatch(String id) => '/courts/$id/current-match';

  /// The next match's line-up, booked while the current one still runs.
  /// `GET` reads it, `POST` sets it, `DELETE` clears it.
  static String courtPreSelect(String id) => '/courts/$id/pre-select';

  /// Server-side matchmaking. The app renders what this returns and never
  /// computes suggestions locally.
  /// Query: `topCount`, `useAi`, `language`, `matchType`.
  static String suggestedPlayers(String courtId) =>
      '/courts/$courtId/suggested-players';

  // --- Payments ------------------------------------------------------------
  static const paymentSettings = '/payment-settings';
  static const paymentQrUpload = '/upload/qr-code';
  static String paymentSetting(String id) => '/payment-settings/$id';
  static String paymentSettingDefault(String id) =>
      '/payment-settings/$id/set-default';
  static String sessionPayments(String id) => '/sessions/$id/payments';
  static String mySessionPayments(String id) => '/sessions/$id/my-payments';
  static String hostPaymentSettings(String hostId) =>
      '/hosts/$hostId/payment-settings';
  static String paymentSubmit(String id) => '/payments/$id/submit';
  static String paymentApprove(String id) => '/payments/$id/approve';
  static String paymentReject(String id) => '/payments/$id/reject';
  static const paymentBulkApprove = '/payments/bulk-approve';
  static const hostPaymentSummary = '/payments/host/summary';
  static const hostFinanceReport = '/payments/host/report';
  static String hostPaymentsForUser(String userId) =>
      '/payments/host/user/$userId';
  static const paymentReminders = '/payment-reminders';
  static const aggregatePaymentReminder = '/payment-reminders/aggregate';
  static const paymentReminderCustom = '/payment-reminders/custom';
  static String paymentReminder(String id) => '/payment-reminders/$id';
  static String paymentReminderRemind(String id) =>
      '/payment-reminders/$id/remind';
  static String paymentReminderMarkCollected(String id) =>
      '/payment-reminders/$id/mark-collected';
  static String paymentReminderMarkPaid(String id) =>
      '/payment-reminders/$id/mark-paid';
  static String paymentReminderReject(String id) =>
      '/payment-reminders/$id/reject';
  static const uploadPaymentProof = '/upload/payment-proof';
  static String sessionPaymentSplit(String id) =>
      '/sessions/$id/payments/split';
  static String sessionFeeConfig(String id) => '/sessions/$id/fee-config';
  static String sessionFeeRecalculate(String id) =>
      '/sessions/$id/fee-config/recalculate';
  static String sessionExpenses(String id) => '/sessions/$id/expenses';
  static String sessionExpense(String sessionId, String expenseId) =>
      '/sessions/$sessionId/expenses/$expenseId';

  // --- Notifications --------------------------------------------------------
  static const notifications = '/notifications';
  static const notificationUnreadCount = '/notifications/unread-count';
  static const notificationReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static String notificationDelete(String id) => '/notifications/$id';

  /// Not implemented on the backend yet — P0 task, see docs/ROADMAP.md.
  static const notificationDevices = '/notifications/devices';

  // --- Feedback -------------------------------------------------------------
  static const feedback = '/feedback';
  static const feedbackUploadImage = '/feedback/upload-image';

  // --- Reference data -------------------------------------------------------
  /// Public. The host-authored blurb for each skill level.
  static const levelDescriptions = '/level-descriptions';
  static const featureFlags = '/feature-flags';

  // --- Favorites ------------------------------------------------------------
  static const favorites = '/favorites';

  /// `type` is the wire enum — `SESSION`, `VENUE`, `CLUB`, `TOURNAMENT`.
  static String favorite(String type, String targetId) =>
      '/favorites/$type/$targetId';
  static String favoriteSummary(String type, String targetId) =>
      '/favorites/$type/$targetId/summary';

  // --- Venues ---------------------------------------------------------------
  static const venues = '/venues';
  static const venueSearch = '/venues/search';
  static String venue(String id) => '/venues/$id';
  static String venuePriceBooks(String id) => '/venues/$id/price-books';
  static const venueRequests = '/venue-requests';
  static const adminVenueRequests = '/venue-requests/admin';
  static const venueAdminUnits = '/venues/new-admin-units';

  // --- Tournaments ---------------------------------------------------------
  /// Public tournament discovery. The backend filters drafts when
  /// `publishedOnly=true`; the client also checks `isPublished` defensively.
  static const tournaments = '/tournaments';

  /// Tournaments the caller hosts, manages or umpires — unpaginated.
  static const myTournaments = '/tournaments/my';
  static String tournament(String id) => '/tournaments/$id';
  static String tournamentMatches(String id) => '/tournaments/$id/all-matches';
  static String tournamentCourts(String id) => '/tournaments/$id/courts';
  static String tournamentUmpires(String id) => '/tournaments/$id/umpires';
  static String tournamentSponsors(String id) => '/tournaments/$id/sponsors';
  static String tournamentMyAccess(String id) => '/tournaments/$id/my-access';
  static String tournamentManagers(String id) => '/tournaments/$id/managers';
  static String tournamentManager(String id, String userId) =>
      '/tournaments/$id/managers/$userId';
  static String duplicateTournament(String id) => '/tournaments/$id/duplicate';
  static String tournamentCategoryGroups(String categoryId) =>
      '/categories/$categoryId/groups';
  static String tournamentStandings(String categoryId) =>
      '/categories/$categoryId/standings';
  static String calculateTournamentStandings(
    String categoryId,
    String groupId,
  ) => '/categories/$categoryId/groups/$groupId/calculate-standings';
  static String categoryMatch(String id) => '/category-matches/$id';
  static String categoryMatchResult(String id) => '/category-matches/$id/end';
  static String categoryMatchReset(String id) =>
      '/category-matches/$id/reset-result';
  static String categoryMatchReferee(String id) =>
      '/category-matches/$id/referee';
  static const categoryMatchAssignments = '/category-matches/my-assignments';
  static const categoryMatchBulkSchedule = '/category-matches/bulk-schedule';
  static String tournamentCompleteGroupStage(String categoryId) =>
      '/categories/$categoryId/complete-group-stage';

  // --- User images ----------------------------------------------------------
  static const userImages = '/user-images';

  // --- AI -------------------------------------------------------------------

  /// Turns a pasted recruitment post into a session draft. Body:
  /// `{articleContent, language}` where language is `vi | en | cn`.
  static const aiExtractSession = '/ai/extract-session';

  /// Streams the AI assistant's plain-text response. Body carries the prior
  /// `messages`, optional `pageContext`, and the selected `language`.
  static const aiChat = '/ai/chat';
}
