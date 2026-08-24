import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/slide_out_menu.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Widget _screen(String label) => Scaffold(
  appBar: AppBar(
    leading: Builder(
      builder: (context) => IconButton(
        icon: const Icon(AppIcons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
    ),
    title: Text(label),
  ),
  drawer: const SlideOutMenu(),
  body: Center(child: Text('$label body')),
);

GoRouter _buildRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, _) => _screen('Home')),
    GoRoute(
      path: AppRoutes.browseSessions,
      builder: (_, _) => _screen('Sessions'),
    ),
    GoRoute(path: AppRoutes.leaderboard, builder: (_, _) => _screen('Rank')),
    GoRoute(path: AppRoutes.manageClubs, builder: (_, _) => _screen('Groups')),
    GoRoute(
      path: AppRoutes.transactions,
      builder: (_, _) => _screen('Transactions'),
    ),
    GoRoute(
      path: AppRoutes.favorites,
      builder: (_, _) => _screen('Favorites'),
    ),
    GoRoute(path: AppRoutes.profile, builder: (_, _) => _screen('Profile')),
    GoRoute(path: AppRoutes.settings, builder: (_, _) => _screen('Settings')),
    GoRoute(path: AppRoutes.feedback, builder: (_, _) => _screen('Feedback')),
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => _screen('Sign in')),
    GoRoute(path: AppRoutes.signUp, builder: (_, _) => _screen('Sign up')),
  ],
);

Widget _harness(AuthState state, GoRouter router) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(() => _TestAuthController(state)),
  ],
  child: MaterialApp.router(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(AppIcons.menu));
  await tester.pumpAndSettle();
}

Future<void> _tapMenuItem(WidgetTester tester, String label) async {
  final item = find.text(label, skipOffstage: false);
  final list = find.byType(ListView);
  for (var attempt = 0; attempt < 10; attempt++) {
    if (item.evaluate().isNotEmpty) {
      final center = tester.getCenter(item);
      if (tester.getRect(list).contains(center)) {
        await tester.tap(item);
        await tester.pumpAndSettle();
        return;
      }
    }
    await tester.drag(list, const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll "$label" into view.');
}

void main() {
  const host = User(
    id: 'host',
    email: 'host@example.com',
    name: 'Nhật Cường',
    role: UserRole.host,
  );

  testWidgets('signed out shows discovery and authentication actions only', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(const AuthState(status: AuthStatus.unauthenticated), router),
    );
    await _openDrawer(tester);

    expect(find.text('Khám phá'), findsOneWidget);
    expect(find.text('Tìm kèo'), findsOneWidget);
    expect(find.text('Tìm sân'), findsOneWidget);
    expect(find.text('Tìm nhóm'), findsOneWidget);
    expect(find.text('Tìm giải'), findsOneWidget);
    expect(find.text('Bảng xếp hạng'), findsOneWidget);
    expect(find.text('Quản lý'), findsNothing);
    expect(find.text('Cài đặt'), findsNothing);
    expect(find.text('Đăng xuất'), findsNothing);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    expect(find.text('© 2026 Vmito.'), findsOneWidget);
    expect(find.textContaining('Tất cả quyền'), findsNothing);
    expect(find.textContaining('v1.4.0'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/icons/app-logo-96.png',
      ),
      findsOneWidget,
    );
  });

  testWidgets('guest has the same restricted menu as a signed-out visitor', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(
          status: AuthStatus.guest,
          user: User(id: 'guest', email: '', role: UserRole.guest),
        ),
        router,
      ),
    );
    await _openDrawer(tester);

    expect(find.text('Cá nhân'), findsNothing);
    expect(find.text('Quản lý'), findsNothing);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });

  testWidgets('discovery destination selects the matching home tab', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(const AuthState(status: AuthStatus.unauthenticated), router),
    );
    await _openDrawer(tester);

    await _tapMenuItem(tester, 'Tìm giải');

    expect(
      router.routeInformationProvider.value.uri,
      Uri.parse(AppRoutes.homeForDiscoveryTab('tournaments')),
    );
    expect(find.byType(SlideOutMenu), findsNothing);
  });

  testWidgets('authenticated host sees profile and management destinations', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(status: AuthStatus.authenticated, user: host),
        router,
      ),
    );
    await _openDrawer(tester);

    expect(find.text('Nhật Cường'), findsOneWidget);
    expect(find.text('Chủ kèo'), findsOneWidget);
    expect(find.text('Quản lý'), findsOneWidget);
    expect(find.text('Kèo'), findsOneWidget);
    expect(find.text('Nhóm'), findsOneWidget);
    expect(find.text('Giao dịch'), findsOneWidget);
    expect(find.text('Yêu thích'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Trợ giúp & phản hồi'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Trợ giúp & phản hồi'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
  });

  testWidgets('profile header uses balanced text and compact height', (
    tester,
  ) async {
    final router = _buildRouter();
    const longName = 'Nguyễn Hoàng Minh Khôi Nguyễn Hoàng Minh Khôi';
    await tester.pumpWidget(
      _harness(
        const AuthState(
          status: AuthStatus.authenticated,
          user: User(
            id: 'long-name-host',
            email: 'long-name-host@example.com',
            name: longName,
            role: UserRole.host,
          ),
        ),
        router,
      ),
    );
    await _openDrawer(tester);

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final name = tester.widget<Text>(find.text(longName));
    final role = tester.widget<Text>(find.text('Chủ kèo'));
    final header = tester.getRect(find.byKey(const Key('menu-profile-header')));
    expect(avatar.radius, 22);
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);
    expect(name.style?.fontSize, lessThanOrEqualTo(18));
    expect(role.style?.fontSize, lessThanOrEqualTo(14));
    expect(header.height, lessThanOrEqualTo(96));
  });

  testWidgets('footer stays compact on one row', (tester) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(const AuthState(status: AuthStatus.unauthenticated), router),
    );
    await _openDrawer(tester);

    final footer = tester.getRect(find.byKey(const Key('menu-footer')));
    final appName = tester.getRect(find.text('Vmito'));
    final year = tester.getRect(find.text('© 2026 Vmito.'));

    expect(footer.height, lessThanOrEqualTo(40));
    expect((appName.center.dy - year.center.dy).abs(), lessThanOrEqualTo(1));
    expect(find.textContaining('Tất cả quyền'), findsNothing);
  });

  testWidgets('player does not see the transaction dashboard', (tester) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(
          status: AuthStatus.authenticated,
          user: User(
            id: 'player',
            email: 'player@example.com',
            role: UserRole.player,
          ),
        ),
        router,
      ),
    );
    await _openDrawer(tester);

    expect(find.text('Giao dịch'), findsNothing);
  });

  testWidgets('management destination closes the drawer and navigates', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(status: AuthStatus.authenticated, user: host),
        router,
      ),
    );
    await _openDrawer(tester);

    await _tapMenuItem(tester, 'Yêu thích');

    expect(find.text('Favorites body'), findsOneWidget);
    expect(find.byType(SlideOutMenu), findsNothing);
  });

  testWidgets('help closes the drawer and opens feedback', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(status: AuthStatus.authenticated, user: host),
        router,
      ),
    );
    await _openDrawer(tester);

    await _tapMenuItem(tester, 'Trợ giúp & phản hồi');
    expect(find.byType(SlideOutMenu), findsNothing);
    expect(find.text('Feedback body'), findsOneWidget);
  });
}
