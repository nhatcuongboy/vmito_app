import 'package:flutter/material.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/slide_out_menu.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// A single route shape shared by every destination: a menu button that
/// opens [SlideOutMenu] plus a label proving which screen is showing, so
/// navigation can be asserted by reading the body text after the drawer
/// closes.
Widget _screen(String label) {
  return Builder(
    builder: (context) => Scaffold(
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
    ),
  );
}

GoRouter _buildRouter() => GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(path: AppRoutes.home, builder: (_, _) => _screen('Home')),
    GoRoute(
      path: AppRoutes.browseSessions,
      builder: (_, _) => _screen('Sessions'),
    ),
    GoRoute(path: AppRoutes.feed, builder: (_, _) => _screen('Feed')),
    GoRoute(path: AppRoutes.profile, builder: (_, _) => _screen('Profile')),
    GoRoute(
      path: AppRoutes.notifications,
      builder: (_, _) => _screen('Notifications'),
    ),
    GoRoute(
      path: AppRoutes.transactions,
      builder: (_, _) => _screen('Transactions'),
    ),
    GoRoute(path: AppRoutes.signIn, builder: (_, _) => _screen('SignIn')),
    GoRoute(path: AppRoutes.signUp, builder: (_, _) => _screen('SignUp')),
  ],
);

Widget _harness(GoRouter router, {required bool isSignedIn}) {
  return ProviderScope(
    overrides: [isSignedInProvider.overrideWithValue(isSignedIn)],
    child: MaterialApp.router(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byIcon(AppIcons.menu));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('signed out: shows core destinations, hides account-only '
      'items, shows sign-in/up', (tester) async {
    await tester.pumpWidget(_harness(_buildRouter(), isSignedIn: false));
    await _openDrawer(tester);

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Kèo'), findsOneWidget);
    expect(find.text('Cộng đồng'), findsOneWidget);
    expect(find.text('Cá nhân'), findsOneWidget);
    expect(find.text('Ngôn ngữ'), findsOneWidget);

    expect(find.text('Thông báo'), findsNothing);
    expect(find.text('Bảng giao dịch'), findsNothing);
    expect(find.text('Đăng nhập'), findsOneWidget);
    expect(find.text('Đăng ký'), findsOneWidget);
  });

  testWidgets('signed in: shows notifications/transactions, hides sign-in/up', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_buildRouter(), isSignedIn: true));
    await _openDrawer(tester);

    expect(find.text('Thông báo'), findsOneWidget);
    expect(find.text('Bảng giao dịch'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
    expect(find.text('Đăng ký'), findsNothing);
  });

  testWidgets('tapping a destination closes the drawer and navigates', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_buildRouter(), isSignedIn: false));
    await _openDrawer(tester);

    await tester.tap(find.text('Cộng đồng'));
    await tester.pumpAndSettle();

    expect(find.text('Feed body'), findsOneWidget);
    expect(find.byType(SlideOutMenu), findsNothing);
  });

  testWidgets('tapping the scrim closes the drawer without navigating', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_buildRouter(), isSignedIn: false));
    await _openDrawer(tester);
    expect(find.byType(SlideOutMenu), findsOneWidget);

    // The drawer occupies the left 280px; the scrim covers the rest.
    await tester.tapAt(const Offset(700, 400));
    await tester.pumpAndSettle();

    expect(find.byType(SlideOutMenu), findsNothing);
    expect(find.text('Home body'), findsOneWidget);
  });
}
