import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_panel_item.dart';
import 'package:vmito_app/features/notification/domain/notification_routing.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/domain/venue_approval_request.dart';

void main() {
  test('groups multi-slot requests and sorts all panel sources', () {
    final items = buildNotificationPanelItems(
      notifications: [
        AppNotification(
          id: 'n1',
          userId: 'u1',
          type: AppNotificationType.system,
          title: 'System',
          message: 'Message',
          isRead: true,
          createdAt: DateTime(2026, 8, 27),
        ),
      ],
      sessionRequests: [
        PendingJoinRequest(
          id: 'p1',
          sessionId: 's1',
          sessionName: 'Session',
          userId: 'u2',
          startTime: DateTime(2026, 8, 30),
        ),
        PendingJoinRequest(
          id: 'p2',
          sessionId: 's1',
          sessionName: 'Session',
          userId: 'u2',
          startTime: DateTime(2026, 8, 30),
        ),
      ],
      clubRequests: [
        ClubJoinRequest(
          id: 'c1',
          userId: 'u3',
          userName: 'Club user',
          userEmail: 'club@example.com',
          createdAt: DateTime(2026, 8, 29),
        ),
      ],
      venueRequests: [
        VenueApprovalRequest(
          id: 'v1',
          type: 'CREATE',
          status: 'PENDING',
          payload: const {'name': 'Venue'},
          createdAt: DateTime(2026, 8, 28),
        ),
      ],
    );

    expect(items, hasLength(4));
    expect(items[0], isA<SessionApprovalItem>());
    expect((items[0] as SessionApprovalItem).slots, hasLength(2));
    expect(items[1], isA<ClubApprovalItem>());
    expect(items[2], isA<VenueApprovalItem>());
    expect(items[3], isA<RegularNotificationItem>());
  });

  test('pending request decodes the grouping and avatar fields', () {
    final request = PendingJoinRequest.fromJson({
      'id': 'p1',
      'sessionId': 's1',
      'createdByUserId': 'owner-1',
      'createdAt': '2026-08-29T08:00:00Z',
      'user': {
        'id': 'u1',
        'name': 'An',
        'image': 'https://example.com/avatar.png',
      },
      'session': {
        'id': 's1',
        'name': 'Kèo tối',
        'startTime': '2026-08-30T11:00:00Z',
      },
    });

    expect(request.playerName, 'An');
    expect(request.userImage, 'https://example.com/avatar.png');
    expect(request.groupKey, 'owner-1-s1');
    expect(request.createdAt, DateTime.utc(2026, 8, 29, 8));
  });

  test('notification exposes web routing and related-user data', () {
    final notification = AppNotification.fromJson({
      'id': 'n1',
      'userId': 'u1',
      'type': 'POST',
      'data': {
        'action': 'post_commented',
        'postId': 'post-1',
        'actorName': 'Minh',
        'actorAvatar': 'avatar.png',
      },
      'createdAt': '2026-08-29T08:00:00Z',
    });

    expect(notification.postId, 'post-1');
    expect(notification.hasRelatedUser, isTrue);
    expect(notification.actorName, 'Minh');
  });

  test('state badge combines unread and every pending source', () {
    final state = NotificationState(
      unreadCount: 2,
      sessionPendingCount: 3,
      clubRequests: [
        ClubJoinRequest(
          id: 'c1',
          userId: 'u1',
          userName: 'An',
          userEmail: 'an@example.com',
          createdAt: DateTime(2026, 8, 29),
        ),
      ],
      venueRequests: [
        VenueApprovalRequest(
          id: 'v1',
          type: 'UPDATE',
          status: 'PENDING',
          payload: const {},
          createdAt: DateTime(2026, 8, 29),
        ),
      ],
    );

    expect(state.pendingApprovalCount, 5);
    expect(state.totalBadgeCount, 7);
  });

  test('resolves the same notification destinations as the web panel', () {
    AppNotification notification(
      AppNotificationType type,
      Map<String, dynamic> data,
    ) => AppNotification(
      id: 'n',
      userId: 'u',
      type: type,
      title: '',
      message: '',
      data: data,
      isRead: false,
      createdAt: DateTime(2026),
    );

    expect(
      getNotificationTargetRoute(
        notification(AppNotificationType.session, const {'sessionId': 's1'}),
        userRole: UserRole.host,
      ),
      '/sessions/s1/manage',
    );
    expect(
      getNotificationTargetRoute(
        notification(AppNotificationType.club, const {'clubSlug': 'smash'}),
        userRole: UserRole.player,
      ),
      '/clubs/smash',
    );
    expect(
      getNotificationTargetRoute(
        notification(AppNotificationType.post, const {'postId': 'p1'}),
      ),
      '/feed/p1',
    );
    expect(
      getNotificationTargetRoute(
        notification(
          AppNotificationType.tournament,
          const {'tournamentId': 't1'},
        ),
      ),
      '/tournaments/t1',
    );
    expect(
      getNotificationTargetRoute(
        notification(AppNotificationType.venueRequest, const {}),
      ),
      '/venues',
    );
    expect(
      getNotificationTargetRoute(
        notification(AppNotificationType.payment, const {}),
      ),
      '/transactions',
    );
  });
}
