import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/login_prompt_dialog.dart';

class _AuthController extends AuthController {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);

  void authenticate({UserRole role = UserRole.player}) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: User(id: 'user', email: 'user@example.com', role: role),
    );
  }

  void signOutForTest() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void explicitSignOutForTest() {
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      wasExplicitlySignedOut: true,
    );
  }
}

// Exercise the production parser, redirects and navigation stack without
// mounting feature screens that fetch unrelated API data.
class _RoutingDelegate extends RouterDelegate<RouteMatchList>
    with ChangeNotifier {
  _RoutingDelegate(this.router, this.target);

  final GoRouter router;
  final String target;

  @override
  RouteMatchList get currentConfiguration =>
      router.routerDelegate.currentConfiguration;

  @override
  Future<void> setNewRoutePath(RouteMatchList configuration) async {
    await router.routerDelegate.setNewRoutePath(configuration);
    notifyListeners();
  }

  @override
  Future<bool> popRoute() async => false;

  @override
  Widget build(BuildContext context) => InheritedGoRouter(
    goRouter: router,
    child: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showLoginPromptDialog(context, targetRoute: target),
            child: const Text('Open feature'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final target in [
    AppRoutes.createSession,
    AppRoutes.createClub,
    AppRoutes.createTournament,
    '/sessions/session-123?tab=players',
    '/venues/venue-123',
  ]) {
    testWidgets('login modal resumes $target after auth state changes', (
      tester,
    ) async {
      final auth = _AuthController();
      final container = ProviderContainer(
        overrides: [authControllerProvider.overrideWith(() => auth)],
      );
      final router = container.read(appRouterProvider);
      final delegate = _RoutingDelegate(router, target);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Router<RouteMatchList>(
            routeInformationProvider: router.routeInformationProvider,
            routeInformationParser: router.routeInformationParser,
            routerDelegate: delegate,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open feature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.home);
      await tester.tap(find.text('Open feature'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.signIn);
      expect(router.state.uri.queryParameters['redirect'], target);

      // No sign-in screen callback: auth can change before its Future finishes
      // (and Apple sign-in relies entirely on the router).
      auth.authenticate(
        role: target == AppRoutes.createTournament
            ? UserRole.host
            : UserRole.player,
      );
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider), same(router));
      expect(router.state.uri.toString(), target);
      expect(
        router.routerDelegate.currentConfiguration.matches.last,
        isNot(isA<ImperativeRouteMatch>()),
      );

      auth.setUser(
        User(
          id: 'user',
          email: 'user@example.com',
          name: 'Updated profile',
          role: target == AppRoutes.createTournament
              ? UserRole.host
              : UserRole.player,
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(appRouterProvider), same(router));
      expect(router.state.uri.toString(), target);

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.createSession));
      await tester.pumpAndSettle();
      auth.signOutForTest();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.signIn);
      expect(
        router.state.uri.queryParameters['redirect'],
        AppRoutes.createSession,
      );

      router.go(AppRoutes.home);
      await tester.pumpAndSettle();
      unawaited(router.push(AppRoutes.signIn));
      await tester.pumpAndSettle();
      auth.authenticate();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.home);

      router.go(AppRoutes.settings);
      await tester.pumpAndSettle();
      auth.explicitSignOutForTest();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.signIn);
      expect(router.state.uri.queryParameters['redirect'], isNull);

      auth.authenticate();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, AppRoutes.home);

      await tester.pumpWidget(const SizedBox.shrink());
      delegate.dispose();
      container.dispose();
    });
  }
}
