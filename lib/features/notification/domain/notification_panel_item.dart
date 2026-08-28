import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/domain/venue_approval_request.dart';

sealed class NotificationPanelItem {
  const NotificationPanelItem(this.timestamp);

  final DateTime timestamp;
}

final class RegularNotificationItem extends NotificationPanelItem {
  RegularNotificationItem(this.notification) : super(notification.createdAt);

  final AppNotification notification;
}

final class SessionApprovalItem extends NotificationPanelItem {
  SessionApprovalItem({
    required this.request,
    required this.slots,
  }) : super(
         request.startTime ??
             request.createdAt ??
             DateTime.fromMillisecondsSinceEpoch(0),
       );

  final PendingJoinRequest request;
  final List<PendingJoinRequest> slots;
}

final class ClubApprovalItem extends NotificationPanelItem {
  ClubApprovalItem(this.request) : super(request.createdAt);

  final ClubJoinRequest request;
}

final class VenueApprovalItem extends NotificationPanelItem {
  VenueApprovalItem(this.request) : super(request.createdAt);

  final VenueApprovalRequest request;
}

List<NotificationPanelItem> buildNotificationPanelItems({
  required List<AppNotification> notifications,
  required List<PendingJoinRequest> sessionRequests,
  required List<ClubJoinRequest> clubRequests,
  required List<VenueApprovalRequest> venueRequests,
}) {
  final items = <NotificationPanelItem>[
    ...notifications.map(RegularNotificationItem.new),
    ...clubRequests.map(ClubApprovalItem.new),
    ...venueRequests.map(VenueApprovalItem.new),
  ];

  final sessionGroups = <String, List<PendingJoinRequest>>{};
  for (final request in sessionRequests) {
    sessionGroups.putIfAbsent(request.groupKey, () => []).add(request);
  }
  for (final slots in sessionGroups.values) {
    items.add(SessionApprovalItem(request: slots.first, slots: slots));
  }

  items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return List.unmodifiable(items);
}
