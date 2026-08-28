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
