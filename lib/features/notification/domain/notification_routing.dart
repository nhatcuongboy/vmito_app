import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';

String? getNotificationTargetRoute(
  AppNotification notification, {
  UserRole? userRole,
}) {
  final action = notification.action;
  if (action == 'session_favorited' && notification.sessionId != null) {
    return AppRoutes.sessionDetail(notification.sessionId!);
  }
  if (action == 'club_favorited' && notification.clubId != null) {
    return AppRoutes.clubDetail(notification.clubId!);
  }
  if (action == 'tournament_favorited' && notification.tournamentId != null) {
    return AppRoutes.tournamentDetail(notification.tournamentId!);
  }

  final route = switch (notification.type) {
    AppNotificationType.session || AppNotificationType.registration =>
      notification.sessionId == null
          ? null
          : userRole == UserRole.host
          ? AppRoutes.manageSession(notification.sessionId!)
          : AppRoutes.sessionDetail(notification.sessionId!),
    AppNotificationType.club =>
      notification.clubId == null
          ? null
          : userRole == UserRole.host
          ? AppRoutes.manageClub(notification.clubId!)
          : AppRoutes.clubDetail(notification.clubId!),
    AppNotificationType.tournament =>
      notification.tournamentId == null
          ? null
          : AppRoutes.tournamentDetail(notification.tournamentId!),
    AppNotificationType.post =>
      notification.postId == null
          ? null
          : AppRoutes.socialPost(notification.postId!),
    AppNotificationType.venueRequest =>
      notification.venueId == null
          ? AppRoutes.venues
          : AppRoutes.venueDetail(notification.venueId!),
    AppNotificationType.venueRental ||
    AppNotificationType.payment => AppRoutes.transactions,
    AppNotificationType.system || AppNotificationType.unknown => null,
  };
  return route ??
      (notification.sessionId != null
          ? AppRoutes.sessionDetail(notification.sessionId!)
          : notification.clubId != null
          ? AppRoutes.clubDetail(notification.clubId!)
          : null);
}

/// Resolves the flat string map carried by an FCM `data` payload.
///
/// The server should always include these routing fields in `data`, even when
/// it also sends a visible `notification` block, so taps work from every app
/// lifecycle state.
String getPushNotificationTargetRoute(
  Map<String, dynamic> data, {
  UserRole? userRole,
}) {
  // A Stream-originated payload (an actual chat message) carries `cid`
  // (`vmito_dm:<channelId>`) instead of Vmito's own `route`/`type` fields —
  // Stream sends this push directly, bypassing vmito-be's notification
  // pipeline entirely. See `isChatPushPayload`.
  final cid = data['cid']?.toString();
  if (cid != null && cid.isNotEmpty) {
    final channelId = cid.contains(':') ? cid.split(':').last : cid;
    if (channelId.isNotEmpty) return AppRoutes.chatChannel(channelId);
  }

  final explicitRoute = data['route']?.toString();
  if (explicitRoute != null &&
      explicitRoute.startsWith('/') &&
      !explicitRoute.startsWith('//')) {
    return explicitRoute;
  }

  final normalized = Map<String, dynamic>.from(data);
  final type = normalized['type']?.toString().toUpperCase() ?? 'UNKNOWN';
  final action = normalized['action']?.toString();
  final sessionId = normalized['sessionId']?.toString();
  if (sessionId != null &&
      sessionId.isNotEmpty &&
      (action == 'court_call' || normalized['courtNumber'] != null)) {
    return AppRoutes.liveSession(sessionId);
  }

  final notification = AppNotification.fromJson({
    'id': normalized['notificationId']?.toString() ?? 'push',
    'userId': normalized['userId']?.toString() ?? '',
    'type': type,
    'title': normalized['title']?.toString() ?? '',
    'message':
        normalized['body']?.toString() ??
        normalized['message']?.toString() ??
        '',
    'data': normalized,
    'isRead': false,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
  });
  return getNotificationTargetRoute(notification, userRole: userRole) ??
      AppRoutes.notifications;
}

/// True for an FCM payload Stream sent directly (a chat message), as opposed
/// to one from vmito-be's own notification pipeline. Used by
/// `PushNotificationLifecycle` to skip the Vmito unread-count refresh and to
/// compare against the currently open channel before showing a local banner.
bool isChatPushPayload(Map<String, dynamic> data) {
  final cid = data['cid']?.toString();
  return cid != null && cid.isNotEmpty;
}

/// The Stream channel id from a chat push payload's `cid`, or null.
String? chatPushChannelId(Map<String, dynamic> data) {
  if (!isChatPushPayload(data)) return null;
  final cid = data['cid']!.toString();
  final channelId = cid.contains(':') ? cid.split(':').last : cid;
  return channelId.isEmpty ? null : channelId;
}
