/// Server event names, mirroring the backend's `SessionEventType` and the
/// enum in `vmito-fe/src/contexts/SocketContext.tsx`.
///
/// Keep this list in step with the backend gateway — a typo here is a silently
/// dead listener.
abstract final class SessionEvent {
  static const sessionUpdated = 'session_updated';
  static const sessionStarted = 'session_started';
  static const sessionCancelled = 'session_cancelled';
  static const playerCreated = 'player_created';
  static const playerUpdated = 'player_updated';
  static const playerRemoved = 'player_removed';
  static const courtUpdated = 'court_updated';
  static const matchStarted = 'match_started';
  static const matchEnded = 'match_ended';

  /// The court call. Payload carries `userId` and `courtNumber`; the app
  /// filters on `userId == currentUserId`, then shows the call UI, fires a
  /// local notification and speaks the announcement.
  static const playersSelected = 'players_selected';
  static const playersDeselected = 'players_deselected';

  static const registrationRequest = 'registration_request';
  static const registrationStatusUpdated = 'registration_status_updated';
  static const notificationReceived = 'notification_received';
  static const favoriteUpdated = 'favorite_updated';
  static const postLikeUpdated = 'post_like_updated';
  static const newPostCreated = 'new_post_created';

  static const all = <String>[
    sessionUpdated,
    sessionStarted,
    sessionCancelled,
    playerCreated,
    playerUpdated,
    playerRemoved,
    courtUpdated,
    matchStarted,
    matchEnded,
    playersSelected,
    playersDeselected,
    registrationRequest,
    registrationStatusUpdated,
    notificationReceived,
    favoriteUpdated,
    postLikeUpdated,
    newPostCreated,
  ];
}

/// Client-emitted events.
abstract final class SocketCommand {
  static const joinSession = 'joinSession';
  static const leaveSession = 'leaveSession';
  static const joinUserRoom = 'join_user_room';
  static const joinTournament = 'joinTournament';
  static const leaveTournament = 'leaveTournament';
}

/// Public tournament-room events from `TournamentsGateway`.
abstract final class TournamentEvent {
  static const matchStarted = 'tournament_match_started';
  static const scoreUpdated = 'tournament_match_score_updated';
  static const matchEnded = 'tournament_match_ended';
  static const refereeAssigned = 'tournament_match_referee_assigned';
  static const scheduleUpdated = 'tournament_schedule_updated';
  static const ended = 'tournament_ended';

  static const all = <String>[
    matchStarted,
    scoreUpdated,
    matchEnded,
    refereeAssigned,
    scheduleUpdated,
    ended,
  ];
}

/// Socket.IO namespaces. The backend serves both at the API origin with
/// `/api` stripped.
abstract final class SocketNamespace {
  /// Authenticated, or an empty token for guests.
  static const sessions = '/sessions';

  /// Token optional — public scoreboards connect anonymously.
  static const tournaments = '/tournaments';
}
