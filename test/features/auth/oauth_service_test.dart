import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/features/auth/data/oauth_service.dart';
import 'package:vmito_app/features/auth/domain/oauth_provider.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

class _RecordingBrowser {
  String? url;
  String? callbackUrlScheme;
  FlutterWebAuth2Options? options;

  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) async {
    this.url = url;
    this.callbackUrlScheme = callbackUrlScheme;
    this.options = options;
    return 'https://vmito.com/vi/auth/callback?'
        'token=access&refreshToken=refresh&userId=user-1&'
        'email=player%40example.com&name=Nguyen%20Van%20A&role=PLAYER';
  }
}

void main() {
  test('parses the same OAuth callback payload as the web app', () {
    final result = OAuthService.parseCallback(
      'https://vmito.com/vi/auth/callback?token=access&'
      'refreshToken=refresh&userId=user-1&email=a%40example.com&'
      'name=Nguyen%20Van%20A&role=HOST&image=https%3A%2F%2Fimg.test%2Fa.png',
    );

    expect(result.accessToken, 'access');
    expect(result.refreshToken, 'refresh');
    expect(result.user.id, 'user-1');
    expect(result.user.email, 'a@example.com');
    expect(result.user.name, 'Nguyen Van A');
    expect(result.user.role, UserRole.host);
    expect(result.user.image, 'https://img.test/a.png');
  });

  test('rejects callbacks that do not contain a complete JWT pair', () {
    expect(
      () => OAuthService.parseCallback(
        'https://vmito.com/vi/auth/callback?token=access',
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('opens the selected backend provider with the current locale', () async {
    final browser = _RecordingBrowser();
    final result = await OAuthService(
      browser.authenticate,
    ).signIn(provider: OAuthProvider.facebook, locale: 'vi');

    final authUri = Uri.parse(browser.url!);
    expect(authUri.path, '/api/auth/facebook');
    expect(authUri.queryParameters['locale'], 'vi');
    expect(browser.callbackUrlScheme, 'https');
    expect(browser.options?.httpsHost, 'vmito.com');
    expect(browser.options?.httpsPath, '/vi/auth/callback');
    expect(result.user.role, UserRole.player);
  });
}
