import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/notification/domain/notification_routing.dart';

void main() {
  test('court call opens the live session', () {
    expect(
      getPushNotificationTargetRoute({
        'type': 'session',
        'action': 'court_call',
        'sessionId': 'session-1',
        'courtNumber': '3',
      }),
      AppRoutes.liveSession('session-1'),
    );
  });

  test('session notification routes hosts to management', () {
    expect(
      getPushNotificationTargetRoute(
        {'type': 'SESSION', 'sessionId': 'session-1'},
        userRole: UserRole.host,
      ),
      AppRoutes.manageSession('session-1'),
    );
  });

  test('unknown notification falls back to the inbox', () {
    expect(
      getPushNotificationTargetRoute({'type': 'something-new'}),
      AppRoutes.notifications,
    );
  });

  test(
    'accepts an internal explicit route but rejects protocol-relative URLs',
    () {
      expect(
        getPushNotificationTargetRoute({'route': '/sessions/session-1'}),
        '/sessions/session-1',
      );
      expect(
        getPushNotificationTargetRoute({'route': '//malicious.example'}),
        AppRoutes.notifications,
      );
    },
  );
}
