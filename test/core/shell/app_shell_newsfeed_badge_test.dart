import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/newsfeed_badge_icon.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    user: User(
      id: 'user-1',
      email: 'user@example.test',
      role: UserRole.player,
    ),
  );
}

class _TestBadgeController extends NewsfeedBadgeController {
  _TestBadgeController(this.count);

  final int count;

  @override
  NewsfeedBadgeState build() => NewsfeedBadgeState(count: count);
}

GoRouter _router() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        for (final path in AppRoutes.shellDestinations)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: path,
                builder: (_, _) => Scaffold(body: Text(path)),
              ),
            ],
          ),
      ],
    ),
  ],
);

Widget _harness(GoRouter router, int count) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_TestAuthController.new),
    newsfeedBadgeControllerProvider.overrideWith(
      () => _TestBadgeController(count),
    ),
  ],
  child: MaterialApp.router(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

void main() {
  testWidgets('bottom navigation shows the shared newsfeed badge', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router, 6));
    await tester.pumpAndSettle();

    expect(find.byType(NewsfeedBadgeIcon), findsWidgets);
    expect(find.text('6'), findsWidgets);
    expect(
      tester.getSemantics(find.byType(NewsfeedBadgeIcon).first).label,
      contains('6 bài chưa đọc'),
    );

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const Key('app-bottom-navigation-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    final palette = AppTheme.light.extension<AppPalette>()!;
    expect(decoration.color, AppTheme.light.colorScheme.surface);
    expect((decoration.border! as Border).top.color, palette.border);
    expect(decoration.boxShadow, isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.getSize(find.byType(NavigationBar)).height,
      AppSizes.bottomNavHeight,
    );
  });

  testWidgets('bottom navigation hides a zero badge', (tester) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router, 0));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
    expect(find.byKey(const Key('newsfeed-unread-badge')), findsNothing);
  });

  testWidgets('navigation labels are clamped below the Material default', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MediaQuery(
        // Above `NavigationBar`'s own 1.3 clamp, so the shell's tighter clamp
        // is what is under test.
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _harness(router, 0),
      ),
    );
    await tester.pumpAndSettle();

    final barContext = tester.element(find.byType(NavigationBar));
    expect(MediaQuery.textScalerOf(barContext).scale(12), 12 * 1.2);
  });
}
