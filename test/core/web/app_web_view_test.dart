import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/web/app_web_view.dart';

void main() {
  group('WebViewSession', () {
    test('parses only the bridge values returned by the backend', () {
      final session = WebViewSession.fromJson({
        'id': 'web-session-1',
        'code': 'one-time-code',
        'expiresAt': '2026-08-26T00:00:00.000Z',
      });

      expect(session.id, 'web-session-1');
      expect(session.code, 'one-time-code');
    });
  });

  test('web page describes a relative Vmito destination', () {
    const page = AppWebPage(
      title: 'Vmito Open',
      path: '/vi/tournament/vmito-open/manage?option=categories',
      requiresAuth: true,
    );

    expect(page.path, startsWith('/'));
    expect(page.requiresAuth, isTrue);
  });

  test('callback keeps locale only on callback path, not return URL', () {
    final uri = AppWebView.buildCallbackUri(
      '/vi/tournament/vmito-open/schedule',
      'one-time-code',
    );
    final fragment = Uri.splitQueryString(uri.fragment);

    expect(uri.path, '/vi/auth/mobile-callback');
    expect(fragment['code'], 'one-time-code');
    expect(fragment['returnUrl'], '/tournament/vmito-open/schedule');
  });
}
