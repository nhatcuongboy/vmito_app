import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/domain/notification_panel_item.dart';
import 'package:vmito_app/features/notification/presentation/notifications_screen.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/venue/domain/venue_approval_request.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeNotificationController extends NotificationController {
  @override
  NotificationState build() => NotificationState(
    items: [
      AppNotification(
        id: 'n1',
        userId: 'u1',
        type: AppNotificationType.session,
        title: 'Your session changed',
        message: 'Court 2 is ready',
        isRead: false,
        createdAt: DateTime(2026, 7, 28, 8),
      ),
    ],
    unreadCount: 1,
    page: 1,
    totalPages: 1,
  );

  @override
  Future<void> load() async {}

  @override
  Future<void> markAllRead() async {
    state = NotificationState(
      items: state.items.map((item) => item.markRead()).toList(),
      page: 1,
      totalPages: 1,
      hasLoaded: true,
    );
  }

  @override
  Future<void> delete(String id) async {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
      unreadCount: 0,
    );
  }
}

void main() {
  testWidgets('renders notification tabs and marks all as read', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _FakeNotificationController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Your session changed'), findsOneWidget);
    expect(find.text('Court 2 is ready'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
    expect(find.byKey(const Key('notification-tab-all')), findsOneWidget);
    expect(find.byKey(const Key('notification-tab-pending')), findsOneWidget);
    expect(
      find.byKey(const Key('notification-tab-information')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('notification-unread-count')), findsNothing);
    expect(find.byKey(const Key('notification-pending-count')), findsNothing);
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mark all read'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('requires confirmation before deleting a notification', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _FakeNotificationController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('delete-notification-n1')),
      findsNothing,
    );
    await tester.drag(find.text('Your session changed'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('swipe-delete-notification-n1')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete notification?'), findsOneWidget);
    expect(find.text('Your session changed'), findsOneWidget);
    expect(find.textContaining('will be permanently deleted'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Your session changed'), findsNothing);
  });

  testWidgets('renders every web panel item without narrow-screen overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _UnifiedNotificationController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Tất cả'), findsOneWidget);
    expect(find.text('Chờ duyệt (4)'), findsOneWidget);
    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('An'), findsOneWidget);
    expect(find.textContaining('2 slot'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('venue-approval-v1')),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Sân Cầu Vồng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('filters regular notifications and approval requests by tab', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _UnifiedNotificationController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notification-tab-information')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('n1')), findsOneWidget);
    expect(find.byKey(const ValueKey('session-approval-p1')), findsNothing);

    await tester.tap(find.byKey(const Key('notification-tab-pending')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('n1')), findsNothing);
    expect(find.byKey(const ValueKey('session-approval-p1')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-approval-c1')), findsOneWidget);
    expect(find.byKey(const ValueKey('venue-approval-v1')), findsOneWidget);
  });

  testWidgets('shows a pending-approval empty state when no requests exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _FakeNotificationController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notification-tab-pending')));
    await tester.pumpAndSettle();

    expect(find.text('Không có yêu cầu nào chờ duyệt.'), findsOneWidget);
  });

  testWidgets('removes a decided approval and updates the pending tab count', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            _SessionApprovalController.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationsScreen(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('notification-tab-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Chờ duyệt (1)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('reject-approval-p1')));
    await tester.pumpAndSettle();

    expect(find.text('Chờ duyệt (0)'), findsOneWidget);
    expect(find.text('Không có yêu cầu nào chờ duyệt.'), findsOneWidget);
  });
}

class _UnifiedNotificationController extends NotificationController {
  @override
  NotificationState build() => NotificationState(
    items: [
      AppNotification(
        id: 'n1',
        userId: 'u1',
        type: AppNotificationType.post,
        title: 'Bình luận mới',
        message: 'Bình luận về bài viết',
        data: const {
          'action': 'post_commented',
          'actorName': 'Minh',
        },
        isRead: false,
        createdAt: DateTime(2026, 8, 29, 10),
      ),
    ],
    sessionRequests: [
      PendingJoinRequest(
        id: 'p1',
        sessionId: 's1',
        sessionName: 'Kèo tối',
        playerName: 'An',
        userId: 'u2',
        startTime: DateTime(2026, 8, 30, 18),
      ),
      PendingJoinRequest(
        id: 'p2',
        sessionId: 's1',
        sessionName: 'Kèo tối',
        playerName: 'An',
        userId: 'u2',
        startTime: DateTime(2026, 8, 30, 18),
      ),
    ],
    clubRequests: [
      ClubJoinRequest(
        id: 'c1',
        userId: 'u3',
        userName: 'Bình',
        userEmail: 'binh@example.com',
        clubId: 'club-1',
        createdAt: DateTime(2026, 8, 28),
        club: const ClubJoinRequestClub(id: 'club-1', name: 'Smash'),
      ),
    ],
    venueRequests: [
      VenueApprovalRequest(
        id: 'v1',
        type: 'CREATE',
        status: 'PENDING',
        payload: const {'name': 'Sân Cầu Vồng'},
        createdAt: DateTime(2026, 8, 27),
      ),
    ],
    unreadCount: 1,
    sessionPendingCount: 2,
    page: 1,
    totalPages: 1,
    hasLoaded: true,
  );

  @override
  Future<void> load() async {}
}

class _SessionApprovalController extends NotificationController {
  @override
  NotificationState build() => NotificationState(
    sessionRequests: [
      PendingJoinRequest(
        id: 'p1',
        sessionId: 's1',
        sessionName: 'Kèo tối',
        userId: 'u2',
        startTime: DateTime(2026, 8, 30, 18),
      ),
    ],
    sessionPendingCount: 1,
    page: 1,
    totalPages: 1,
    hasLoaded: true,
  );

  @override
  Future<void> load() async {}

  @override
  Future<bool> decideSessionRequest(
    SessionApprovalItem group, {
    required bool approved,
  }) async {
    final requestIds = group.slots.map((request) => request.id).toSet();
    state = state.copyWith(
      sessionRequests: state.sessionRequests
          .where((request) => !requestIds.contains(request.id))
          .toList(),
      sessionPendingCount: state.sessionPendingCount - requestIds.length,
    );
    return true;
  }
}
