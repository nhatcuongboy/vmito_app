/// Server event names, mirroring the backend's `SessionEventType` and the
/// enum in `vmito-fe/src/contexts/SocketContext.tsx`.
///
/// Keep this list in step with the backend gateway — a typo here is a silently
/// dead listener.
abstract final class SessionEvent {
  static const sessionUpdated = 'session_updated';
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

  static const all = <String>[
    sessionUpdated,
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
  ];
}

/// Client-emitted events.
abstract final class SocketCommand {
  static const joinSession = 'join_session';
  static const leaveSession = 'leave_session';
  static const joinTournament = 'join_tournament';
  static const leaveTournament = 'leave_tournament';
}

/// Socket.IO namespaces. The backend serves both at the API origin with
/// `/api` stripped.
abstract final class SocketNamespace {
  /// Authenticated, or an empty token for guests.
  static const sessions = '/sessions';

  /// Token optional — public scoreboards connect anonymously.
  static const tournaments = '/tournaments';
}
