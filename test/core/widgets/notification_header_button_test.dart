import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/notification_header_button.dart';
import 'package:vmito_app/features/notification/application/notification_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _FakeNotificationController extends NotificationController {
  _FakeNotificationController(this.unreadCount, {this.pendingCount = 0});

  final int unreadCount;
  final int pendingCount;

  @override
  NotificationState build() => NotificationState(
    unreadCount: unreadCount,
    sessionPendingCount: pendingCount,
  );

  @override
  Future<void> refreshUnreadCount() async {}
}

void main() {
  testWidgets('shows the unread notification count as a badge', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(3),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationHeaderButton(),
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(NotificationHeaderButton)).label,
      'Thông báo: 3',
    );
  });

  testWidgets('hides the badge when every notification is read', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(0),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: NotificationHeaderButton(),
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
  });

  testWidgets('includes pending approvals in the header badge', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationControllerProvider.overrideWith(
            () => _FakeNotificationController(2, pendingCount: 4),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: NotificationHeaderButton()),
        ),
      ),
    );

    expect(find.text('6'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(NotificationHeaderButton)).label,
      'Thông báo: 6',
    );
  });
}
