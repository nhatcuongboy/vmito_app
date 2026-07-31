import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/notification/domain/app_notification.dart';

void main() {
  test('decodes notification payload and resolves session target', () {
    final notification = AppNotification.fromJson({
      'id': 'n1',
      'userId': 'u1',
      'type': 'SESSION',
      'title': 'Court updated',
      'message': 'A court changed',
      'data': {'sessionId': 's1'},
      'isRead': false,
      'createdAt': '2026-07-28T08:00:00.000Z',
    });
    expect(notification.type, AppNotificationType.session);
    expect(notification.sessionId, 's1');
    expect(notification.markRead().isRead, isTrue);
  });

  test('unknown types and malformed optional data stay safe', () {
    final notification = AppNotification.fromJson({
      'id': 'n2',
      'userId': 'u1',
      'type': 'NEW_TYPE',
      'isRead': true,
    });
    expect(notification.type, AppNotificationType.unknown);
    expect(notification.sessionId, isNull);
  });
}
