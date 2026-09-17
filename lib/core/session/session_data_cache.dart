import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/chat/application/active_chat_channel.dart';
import 'package:vmito_app/features/chat/application/chat_requests_controller.dart';
import 'package:vmito_app/features/chat/application/chat_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/favorite/application/favorite_controller.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/payment/application/payment_providers.dart';
import 'package:vmito_app/features/payment/application/payment_reminders_controller.dart';
import 'package:vmito_app/features/payment/application/player_session_payment_controller.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/application/my_registration_controller.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/host_detail_controller.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/application/player/session_recommendations_controller.dart';
import 'package:vmito_app/features/session_hosting/application/host_session_management_controller.dart';
import 'package:vmito_app/features/session_hosting/application/hosted_sessions_controller.dart';
import 'package:vmito_app/features/session_hosting/application/player_statistics_providers.dart';
import 'package:vmito_app/features/social/application/club_management_controller.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/features/social/application/post_comments_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_detail_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_management_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_schedule_controller.dart';
import 'package:vmito_app/features/tournament/application/tournament_standings_controller.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';

/// Drops every in-memory API result that can contain account-specific data.
///
/// The app deliberately keeps each shell branch alive. That is useful while a
/// single account navigates between tabs, but the same cache must never cross
/// an authentication boundary. Invalidating provider families clears all of
/// their currently-created arguments as well.
void invalidateSessionData(ProviderContainer container) {
  final providers = [
    browseSessionsControllerProvider,
    mySessionsControllerProvider,
    sessionDetailProvider,
    hostDetailStatsProvider,
    sessionRecommendationsProvider,
    matchHistoryProvider,
    playerMatchHistoryProvider,
    myJoinRequestsControllerProvider,
    myRegistrationProvider,
    myRegistrationStatusProvider,
    myRegistrationStatusesProvider,
    hostedSessionsProvider,
    hostSessionManagementControllerProvider,
    playerStatisticsProvider,
    playerDetailProvider,
    showShuttlecockCountProvider,
    favoriteControllerProvider,
    feedControllerProvider,
    postCommentsControllerProvider,
    postDetailProvider,
    clubsControllerProvider,
    clubDetailProvider,
    publicUserProvider,
    publicProfileProvider,
    batchRatingStatsProvider,
    ratingEligibilityProvider,
    newsfeedBadgeControllerProvider,
    hostFeatureAccessProvider,
    managedClubsProvider,
    myClubsProvider,
    myClubRequestsProvider,
    incomingClubRequestsProvider,
    pendingClubsProvider,
    managedClubProvider,
    clubMembersProvider,
    clubFeeProvider,
    clubMonthlyMembersProvider,
    clubJoinRequestsProvider,
    clubAnnouncementsProvider,
    clubUserSearchProvider,
    clubHostUsersProvider,
    clubManagementControllerProvider,
    notificationControllerProvider,
    leaderboardControllerProvider,
    paymentLedgerProvider,
    paymentSettingsProvider,
    sessionExpensesProvider,
    sessionFeeConfigProvider,
    paymentRemindersProvider,
    hostTransactionSummaryProvider,
    hostUserTransactionsProvider,
    hostFinanceReportProvider,
    remindersListProvider,
    reminderUserSearchProvider,
    playerSessionPaymentsProvider,
    tournamentBrowseControllerProvider,
    tournamentTitleProvider,
    tournamentDetailControllerProvider,
    tournamentStandingsControllerProvider,
    tournamentScheduleControllerProvider,
    tournamentManagementControllerProvider,
    tournamentManagersProvider,
    tournamentUserSearchProvider,
    tournamentImageLibraryProvider,
    tournamentVenueSearchProvider,
    tournamentManageAccessProvider,
    venueBrowseControllerProvider,
    venueDetailProvider,
    venuePriceBooksProvider,
    chatSessionControllerProvider,
    chatRequestsControllerProvider,
    activeChatChannelIdProvider,
  ];

  // The callback receiver is intentionally the container, not this local list.
  // ignore: cascade_invocations
  providers.forEach(container.invalidate);
}
