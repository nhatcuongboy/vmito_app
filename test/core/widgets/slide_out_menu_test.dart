import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
  final listBottom = tester.getBottomLeft(find.byType(ListView)).dy;
  for (var attempt = 0; attempt < 5; attempt++) {
    final center = tester.getCenter(item);
    if (center.dy >= 0 && center.dy <= listBottom) {
      await tester.tap(item);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(find.byType(ListView), const Offset(0, -240));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll "$label" into view.');
}

void main() {
  setUpAll(() {
    PackageInfo.setMockInitialValues(
      appName: 'Vmito',
      packageName: 'com.vmito.app',
      version: '1.4.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

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
    expect(
      find.textContaining(
        'v1.4.0 · © 2026 Vmito. Tất cả quyền được bảo lưu.',
        findRichText: true,
      ),
      findsOneWidget,
    );
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
    expect(
      find.text('Trợ giúp & phản hồi', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Đăng nhập'), findsNothing);
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

  testWidgets('help keeps the drawer open and sign out asks for confirmation', (
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
    expect(find.byType(SlideOutMenu), findsOneWidget);
    expect(find.text('Home body'), findsOneWidget);

    await _tapMenuItem(tester, 'Đăng xuất');
    expect(find.text('Bạn có chắc chắn muốn đăng xuất?'), findsOneWidget);
  });
}
