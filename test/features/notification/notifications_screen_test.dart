import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';
import 'package:vmito_app/features/notification/presentation/notifications_screen.dart';
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
    );
  }
}

void main() {
  testWidgets('renders unread notification and marks all as read', (
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
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(find.text('Mark all read'), findsNothing);
  });
}
