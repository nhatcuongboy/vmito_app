import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// Maps notification action to translation key configuration
class _NotificationTranslationKeys {
  const _NotificationTranslationKeys({
    required this.titleKey,
    required this.messageKey,
  });

  final String Function(AppLocalizations) titleKey;
  final String Function(AppLocalizations, Map<String, String>) messageKey;
}

/// Notification action to translation keys mapping
final Map<String, _NotificationTranslationKeys> _actionToKeys = {
  'start_reminder': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationStartReminderTitle,
    messageKey: (l10n, params) =>
        l10n.notificationStartReminderMessage(params['sessionName'] ?? ''),
  ),
  'player_start_reminder': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationPlayerStartReminderTitle,
    messageKey: (l10n, params) => l10n.notificationPlayerStartReminderMessage(
      params['sessionName'] ?? '',
    ),
  ),
  'players_selected': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationYourTurnTitle,
    messageKey: (l10n, params) =>
        l10n.notificationYourTurnMessage(params['courtName'] ?? ''),
  ),
  'auto_started': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationAutoStartedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationAutoStartedMessage(params['sessionName'] ?? ''),
  ),
  'session_auto_started': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationSessionAutoStartedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationSessionAutoStartedMessage(params['sessionName'] ?? ''),
  ),
  'auto_cancelled': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationAutoCancelledTitle,
    messageKey: (l10n, params) =>
        l10n.notificationAutoCancelledMessage(params['sessionName'] ?? ''),
  ),
  'session_cancelled': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationSessionCancelledTitle,
    messageKey: (l10n, params) =>
        l10n.notificationSessionCancelledMessage(params['sessionName'] ?? ''),
  ),
  'end_warning': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationEndWarningTitle,
    messageKey: (l10n, params) =>
        l10n.notificationEndWarningMessage(params['sessionName'] ?? ''),
  ),
  'auto_finalized': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationAutoFinalizedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationAutoFinalizedMessage(params['sessionName'] ?? ''),
  ),
  'club_creation_pending': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationClubCreationPendingTitle,
    messageKey: (l10n, params) =>
        l10n.notificationClubCreationPendingMessage(params['clubName'] ?? ''),
  ),
  'admin_new_pending_club': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationAdminNewPendingClubTitle,
    messageKey: (l10n, params) =>
        l10n.notificationAdminNewPendingClubMessage(params['clubName'] ?? ''),
  ),
  'club_creation_approved': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationClubCreationApprovedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationClubCreationApprovedMessage(params['clubName'] ?? ''),
  ),
  'club_approved': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationClubApprovedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationClubApprovedMessage(params['clubName'] ?? ''),
  ),
  'club_rejected': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationClubRejectedTitle,
    messageKey: (l10n, params) => l10n.notificationClubRejectedMessage(
      params['clubName'] ?? '',
      params['rejectionReason'] ?? '',
    ),
  ),
  'player_added': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationPlayerAddedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationPlayerAddedMessage(params['sessionName'] ?? ''),
  ),
  'player_removed': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationPlayerRemovedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationPlayerRemovedMessage(params['sessionName'] ?? ''),
  ),
  'post_liked': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationPostLikedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationPostLikedMessage(params['actorName'] ?? ''),
  ),
  'post_commented': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationPostCommentedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationPostCommentedMessage(params['actorName'] ?? ''),
  ),
  'session_favorited': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationSessionFavoritedTitle,
    messageKey: (l10n, params) => l10n.notificationSessionFavoritedMessage(
      params['actorName'] ?? '',
      params['sessionName'] ?? '',
    ),
  ),
  'club_favorited': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationClubFavoritedTitle,
    messageKey: (l10n, params) => l10n.notificationClubFavoritedMessage(
      params['actorName'] ?? '',
      params['clubName'] ?? '',
    ),
  ),
  'tournament_favorited': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationTournamentFavoritedTitle,
    messageKey: (l10n, params) => l10n.notificationTournamentFavoritedMessage(
      params['actorName'] ?? '',
      params['tournamentName'] ?? '',
    ),
  ),
  'venue_request_approved': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationVenueRequestApprovedTitle,
    messageKey: (l10n, params) =>
        l10n.notificationVenueRequestApprovedMessage(params['venueName'] ?? ''),
  ),
  'venue_request_rejected': _NotificationTranslationKeys(
    titleKey: (l10n) => l10n.notificationVenueRequestRejectedTitle,
    messageKey: (l10n, params) => l10n.notificationVenueRequestRejectedMessage(
      params['venueName'] ?? '',
      params['rejectionReason'] ?? '',
    ),
  ),
};

/// Extracts translation parameters from notification data
Map<String, String> _getTranslationParams(AppNotification notification) {
  final data = notification.data;
  final params = <String, String>{};

  // Extract session name
  final sessionName = data['sessionName'];
  if (sessionName is String && sessionName.isNotEmpty) {
    params['sessionName'] = sessionName;
  }

  // Extract club name
  final clubName = data['clubName'];
  if (clubName is String && clubName.isNotEmpty) {
    params['clubName'] = clubName;
  }

  // Extract tournament name
  final tournamentName = data['tournamentName'];
  if (tournamentName is String && tournamentName.isNotEmpty) {
    params['tournamentName'] = tournamentName;
  }

  // Extract venue name
  final venueName = data['venueName'] ?? data['name'];
  if (venueName is String && venueName.isNotEmpty) {
    params['venueName'] = venueName;
    params['venue'] = venueName;
  }

  // Extract actor name
  final actorName = data['actorName'];
  if (actorName is String && actorName.isNotEmpty) {
    params['actorName'] = actorName;
  }

  // Extract rejection reason
  final rejectionReason = data['rejectionReason'] ?? data['adminNote'];
  if (rejectionReason is String && rejectionReason.isNotEmpty) {
    params['rejectionReason'] = rejectionReason;
    params['adminNote'] = rejectionReason;
  }

  // Extract court name
  final courtName =
      data['courtName'] ?? data['courtDisplayName'] ?? data['court'];
  if (courtName is String && courtName.isNotEmpty) {
    params['courtName'] = courtName;
    params['court'] = courtName;
  }

  return params;
}

/// Gets localized display text for a notification
({String displayTitle, String displayMessage}) getNotificationDisplayText(
  AppNotification notification,
  AppLocalizations l10n,
) {
  final action = notification.data['action'];
  if (action is! String) {
    // No action specified, use backend-provided title/message
    return (
      displayTitle: notification.title,
      displayMessage: notification.message,
    );
  }

  final keys = _actionToKeys[action];
  if (keys == null) {
    // No translation keys found for this action, use backend message
    return (
      displayTitle: notification.title,
      displayMessage: notification.message,
    );
  }

  try {
    final params = _getTranslationParams(notification);
    final displayTitle = keys.titleKey(l10n);
    final displayMessage = keys.messageKey(l10n, params);

    return (displayTitle: displayTitle, displayMessage: displayMessage);
  } on Exception catch (_) {
    // On any error, fallback to backend-provided title/message
    return (
      displayTitle: notification.title,
      displayMessage: notification.message,
    );
  }
}
