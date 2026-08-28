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

  group('authentication bridge', () {
    test('does not authenticate public pages when an access token exists', () {
      const page = AppWebPage(
        title: 'HCM Open Cup 2026',
        path: '/vi/tournament/hcm-open-cup-2026',
      );

      expect(
        AppWebView.shouldBridgeAuthentication(page, hasToken: true),
        isFalse,
      );
    });

    test('authenticates protected pages when an access token exists', () {
      const page = AppWebPage(
        title: 'Manage tournament',
        path: '/vi/tournament/hcm-open-cup-2026/manage',
        requiresAuth: true,
      );

      expect(
        AppWebView.shouldBridgeAuthentication(page, hasToken: true),
        isTrue,
      );
    });

    test('does not authenticate a protected page without an access token', () {
      const page = AppWebPage(
        title: 'Manage tournament',
        path: '/vi/tournament/hcm-open-cup-2026/manage',
        requiresAuth: true,
      );

      expect(
        AppWebView.shouldBridgeAuthentication(page, hasToken: false),
        isFalse,
      );
    });
  });

  test('embedded page marker keeps existing query parameters', () {
    const page = AppWebPage(
      title: 'Manage tournament',
      path: '/vi/tournament/vmito-open/manage?option=categories',
      embedded: true,
    );

    expect(
      AppWebView.resolvedPath(page),
      '/vi/tournament/vmito-open/manage?option=categories&embedded=1',
    );
  });

  test('embedded page marker replaces a stale embedded value', () {
    const page = AppWebPage(
      title: 'Admin',
      path: '/vi/admin?embedded=0',
      embedded: true,
    );

    expect(AppWebView.resolvedPath(page), '/vi/admin?embedded=1');
  });

  test('callback keeps locale only on callback path, not return URL', () {
    final uri = AppWebView.buildCallbackUri(
      '/vi/tournament/vmito-open/schedule?embedded=1',
      'one-time-code',
    );
    final fragment = Uri.splitQueryString(uri.fragment);

    expect(uri.path, '/vi/auth/mobile-callback');
    expect(fragment['code'], 'one-time-code');
    expect(fragment['returnUrl'], '/tournament/vmito-open/schedule?embedded=1');
  });
}
