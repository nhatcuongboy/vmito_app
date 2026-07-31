import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:vmito_app/core/storage/token_storage.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/data/oauth_service.dart';
import 'package:vmito_app/features/auth/presentation/sign_in_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

import '../../support/fake_secure_storage.dart';

class _CompletingBrowser {
  int calls = 0;
  String? lastUrl;

  Future<String> authenticate({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) async {
    calls += 1;
    lastUrl = url;
    return 'https://vmito.com/vi/auth/callback?token=access&'
        'refreshToken=refresh&userId=user-1&email=a%40example.com&'
        'name=Player&role=PLAYER';
  }
}

void main() {
  testWidgets('renders both providers and Google completes the app session', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final browser = _CompletingBrowser();
    final container = ProviderContainer(
      overrides: [
        oauthAuthenticateProvider.overrideWithValue(browser.authenticate),
        tokenStorageProvider.overrideWithValue(
          TokenStorage(FakeSecureStorage()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: const SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(find.text('Tiếp tục với Facebook'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('oauth-google')));
    await tester.pumpAndSettle();

    expect(browser.calls, 1);
    expect(Uri.parse(browser.lastUrl!).path, '/api/auth/google');
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(container.read(authControllerProvider).user?.id, 'user-1');
  });
}
