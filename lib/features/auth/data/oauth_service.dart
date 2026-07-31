import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_exception.dart';
import 'package:vmito_app/features/auth/domain/oauth_provider.dart';
import 'package:vmito_app/features/auth/domain/user.dart';

typedef OAuthAuthenticate =
    Future<String> Function({
      required String url,
      required String callbackUrlScheme,
      required FlutterWebAuth2Options options,
    });

/// Runs the backend-owned Google/Facebook OAuth flow in a secure browser tab.
///
/// The backend always redirects to the web app's `/{locale}/auth/callback`
/// URL. `flutter_web_auth_2` captures that HTTPS redirect before the page is
/// loaded, so the mobile app receives the same token payload as the web app
/// without embedding provider login pages in an unsafe WebView.
class OAuthService {
  const OAuthService(this._authenticate);

  final OAuthAuthenticate _authenticate;

  Future<LoginResponse> signIn({
    required OAuthProvider provider,
    required String locale,
  }) async {
    final callbackBase = Uri.parse(AppConfig.webBaseUrl);
    final callbackPath = '/$locale/auth/callback';
    final endpoint = switch (provider) {
      OAuthProvider.google => ApiEndpoints.oauthGoogle,
      OAuthProvider.facebook => ApiEndpoints.oauthFacebook,
    };
    final authUri = Uri.parse('${AppConfig.apiBaseUrl}$endpoint').replace(
      queryParameters: {'locale': locale},
    );

    final callback = await _authenticate(
      url: authUri.toString(),
      callbackUrlScheme: callbackBase.scheme,
      options: FlutterWebAuth2Options(
        httpsHost: callbackBase.scheme == 'https' ? callbackBase.host : null,
        httpsPath: callbackBase.scheme == 'https' ? callbackPath : null,
      ),
    );

    return parseCallback(callback);
  }

  /// Converts the web callback contract into the app's normal login result.
  /// Kept public and pure so malformed redirects can be regression-tested.
  static LoginResponse parseCallback(String callback) {
    final query = Uri.parse(callback).queryParameters;
    final accessToken = query['token'];
    final refreshToken = query['refreshToken'];
    final userId = query['userId'];
    final email = query['email'];
    final role = query['role'];

    if ([accessToken, refreshToken, userId, email, role].any(
      (value) => value == null || value.isEmpty,
    )) {
      throw const ApiException(
        kind: ApiErrorKind.validation,
        message: 'OAuth callback is missing required authentication data.',
      );
    }

    try {
      final user = User.fromJson({
        'id': userId,
        'email': email,
        'name': query['name'],
        'role': role,
        'image': query['image'],
      });
      return LoginResponse(
        accessToken: accessToken!,
        refreshToken: refreshToken!,
        user: user,
      );
    } on Object catch (error) {
      throw ApiException(
        kind: ApiErrorKind.validation,
        message: 'OAuth callback contains invalid user data.',
        raw: error,
      );
    }
  }
}

final oauthAuthenticateProvider = Provider<OAuthAuthenticate>(
  (ref) => FlutterWebAuth2.authenticate,
);

final oauthServiceProvider = Provider<OAuthService>(
  (ref) => OAuthService(ref.watch(oauthAuthenticateProvider)),
);
