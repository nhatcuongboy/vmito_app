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
import 'package:vmito_app/features/social/application/newsfeed_badge_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

class _TestNewsfeedBadgeController extends NewsfeedBadgeController {
  @override
  NewsfeedBadgeState build() => const NewsfeedBadgeState(count: 5);
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
    GoRoute(path: AppRoutes.feed, builder: (_, _) => _screen('Feed')),
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

Widget _harness(
  AuthState state,
  GoRouter router, {
  Locale locale = const Locale('vi'),
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(() => _TestAuthController(state)),
    newsfeedBadgeControllerProvider.overrideWith(
      _TestNewsfeedBadgeController.new,
    ),
  ],
  child: MaterialApp.router(
    locale: locale,
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
    expect(find.text('Bảng tin'), findsNothing);
    expect(find.text('ADMIN'), findsNothing);
    expect(find.text('Quản lý'), findsNothing);
    expect(find.text('Cài đặt'), findsNothing);
    expect(find.text('Đăng xuất'), findsNothing);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ngôn ngữ'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Ngôn ngữ'), findsOneWidget);
    expect(find.text('Giao diện'), findsOneWidget);
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
    expect(find.text('ADMIN'), findsNothing);
    expect(find.text('Đăng nhập'), findsOneWidget);
  });

  testWidgets('uses compact, role-based drawer typography', (tester) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(const AuthState(status: AuthStatus.unauthenticated), router),
    );
    await _openDrawer(tester);

    final section = tester.widget<Text>(find.text('Khám phá'));
    final activeItem = tester.widget<Text>(find.text('Tìm kèo'));
    final inactiveItem = tester.widget<Text>(find.text('Tìm sân'));
    final activeTile = find.ancestor(
      of: find.text('Tìm kèo'),
      matching: find.byType(ListTile),
    );
    final activeIcon = find.descendant(
      of: activeTile,
      matching: find.byIcon(AppIcons.sessions),
    );
    final signIn = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('Đăng nhập'),
        matching: find.byType(OutlinedButton),
      ),
    );

    expect(section.style?.fontSize, 12);
    expect(section.style?.height, closeTo(16 / 12, 0.0001));
    expect(section.style?.fontWeight, FontWeight.w700);
    expect(activeItem.style?.fontSize, 15);
    expect(activeItem.style?.height, closeTo(20 / 15, 0.0001));
    expect(activeItem.style?.fontWeight, FontWeight.w600);
    expect(activeItem.maxLines, 1);
    expect(activeItem.overflow, TextOverflow.ellipsis);
    expect(inactiveItem.style?.fontWeight, FontWeight.w500);
    expect(tester.getSize(activeTile).height, 48);
    expect(IconTheme.of(tester.element(activeIcon)).size, 22);
    expect(
      signIn.style?.textStyle?.resolve(<WidgetState>{})?.fontSize,
      14,
    );
    expect(
      signIn.style?.textStyle?.resolve(<WidgetState>{})?.fontWeight,
      FontWeight.w600,
    );

    await tester.scrollUntilVisible(
      find.text('Tiếng Việt'),
      240,
      scrollable: find.byType(Scrollable),
    );
    final trailing = tester.widget<Text>(find.text('Tiếng Việt'));
    final footerName = tester.widget<Text>(find.text('Vmito'));
    final footerYear = tester.widget<Text>(find.text('© 2026 Vmito.'));
    expect(trailing.style?.fontSize, 14);
    expect(trailing.style?.fontWeight, FontWeight.w500);
    expect(trailing.maxLines, 1);
    expect(trailing.overflow, TextOverflow.ellipsis);
    expect(footerName.style?.fontSize, 14);
    expect(footerName.style?.fontWeight, FontWeight.w700);
    expect(footerYear.style?.fontSize, 12);
    expect(footerYear.style?.fontWeight, FontWeight.w400);
  });

  testWidgets('drawer does not overflow across locales and text scales', (
    tester,
  ) async {
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      return tester.binding.setSurfaceSize(null);
    });

    for (final width in const [320.0, 360.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      for (final scale in const [1.0, 1.3, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        for (final locale in AppLocalizations.supportedLocales) {
          final router = _buildRouter();
          await tester.pumpWidget(
            _harness(
              const AuthState(status: AuthStatus.unauthenticated),
              router,
              locale: locale,
            ),
          );
          await _openDrawer(tester);

          expect(find.byType(SlideOutMenu), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          router.dispose();
        }
      }
    }
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
    expect(find.text('ADMIN'), findsNothing);
    expect(find.text('Yêu thích'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Trợ giúp & phản hồi'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Trợ giúp & phản hồi'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
  });

  testWidgets('administrator sees every embedded admin destination', (
    tester,
  ) async {
    final router = _buildRouter();
    await tester.pumpWidget(
      _harness(
        const AuthState(
          status: AuthStatus.authenticated,
          user: User(
            id: 'admin',
            email: 'admin@example.com',
            role: UserRole.admin,
          ),
        ),
        router,
      ),
    );
    await _openDrawer(tester);

    await tester.scrollUntilVisible(
      find.text('ADMIN'),
      240,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('ADMIN'), findsOneWidget);
    for (final label in const [
      'Bảng điều khiển',
      'Người dùng',
      'Quản lý kèo (Admin)',
      'Thông báo',
      'Liên hệ & Báo lỗi',
      'Cài đặt chung',
      'Mô tả trình độ',
      'Điểm & xếp hạng',
      'Sân bãi',
      'Duyệt nhóm',
    ]) {
      await tester.scrollUntilVisible(
        find.text(label),
        240,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(label), findsOneWidget);
    }
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
    expect(name.style?.fontSize, 16);
    expect(name.style?.height, closeTo(20 / 16, 0.0001));
    expect(name.style?.fontWeight, FontWeight.w700);
    expect(role.style?.fontSize, 12);
    expect(role.style?.height, closeTo(16 / 12, 0.0001));
    expect(role.style?.fontWeight, FontWeight.w500);
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
