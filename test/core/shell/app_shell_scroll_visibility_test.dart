import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/shell/app_shell.dart';
import 'package:vmito_app/core/shell/tab_reselection_controller.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/slide_out_menu.dart';
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
  @override
  NewsfeedBadgeState build() => const NewsfeedBadgeState();
}

GoRouter _router(Widget home, {Widget? otherBranch}) => GoRouter(
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
                builder: (_, _) => Scaffold(
                  body: path == AppRoutes.home
                      ? home
                      : otherBranch ?? Text(path),
                ),
                routes: path == AppRoutes.home
                    ? [
                        GoRoute(
                          path: 'detail',
                          builder: (_, _) => const Scaffold(
                            body: Text('Detail'),
                          ),
                        ),
                      ]
                    : const [],
              ),
            ],
          ),
      ],
    ),
  ],
);

Widget _harness(GoRouter router) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(_TestAuthController.new),
    newsfeedBadgeControllerProvider.overrideWith(_TestBadgeController.new),
  ],
  child: MaterialApp.router(
    locale: const Locale('vi'),
    theme: AppTheme.light,
    routerConfig: router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  ),
);

Widget _list({required int itemCount, ScrollController? controller}) =>
    ListView.builder(
      key: const Key('test-list'),
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      itemExtent: 50,
      itemCount: itemCount,
      itemBuilder: (_, index) => Text('Item $index'),
    );

Widget _feedLikeScrollView() => CustomScrollView(
  key: const Key('test-feed'),
  slivers: [
    const SliverToBoxAdapter(child: SizedBox(height: 100)),
    SliverList.builder(
      itemCount: 40,
      itemBuilder: (_, index) => SizedBox(
        height: 100,
        child: Text('Post $index'),
      ),
    ),
  ],
);

class _StatusBarScrollable extends ConsumerStatefulWidget {
  const _StatusBarScrollable();

  @override
  ConsumerState<_StatusBarScrollable> createState() =>
      _StatusBarScrollableState();
}

class _StatusBarScrollableState extends ConsumerState<_StatusBarScrollable> {
  final _controller = ScrollController();
  late final VoidCallback _removeHandler;

  @override
  void initState() {
    super.initState();
    _removeHandler = ref
        .read(tabReselectionControllerProvider)
        .register(
          tabIndex: 0,
          onReselect: () => scrollToTop(_controller),
        );
  }

  @override
  void dispose() {
    _removeHandler();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _list(
    itemCount: 40,
    controller: _controller,
  );
}

double _bottomBarHeight(WidgetTester tester) => tester
    .getSize(find.byKey(const Key('app-bottom-navigation-reveal')))
    .height;

void main() {
  testWidgets('status-bar tap scrolls the current tab to the top', (
    tester,
  ) async {
    final router = _router(const _StatusBarScrollable());
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const Key('test-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('test-list')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(scrollable.position.pixels, greaterThan(0));

    final message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('handleScrollToTop'),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('flutter/status_bar', message, (_) {});
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, 0);
  });

  testWidgets('long content uses a drag threshold to hide and show the bar', (
    tester,
  ) async {
    final router = _router(_list(itemCount: 40));
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), greaterThan(0));

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -12));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), greaterThan(0));

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), 0);

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, 40));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), greaterThan(0));
  });

  testWidgets('observes a vertical list nested in a horizontal page view', (
    tester,
  ) async {
    final router = _router(PageView(children: [_list(itemCount: 40)]));
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -40));
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), 0);
  });

  testWidgets('feed-like custom scroll view hides for trackpad scrolling', (
    tester,
  ) async {
    final router = _router(_feedLikeScrollView());
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.trackpadFling(
      find.byKey(const Key('test-feed')),
      const Offset(0, -60),
      200,
    );
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), 0);
  });

  testWidgets('small mouse-wheel ticks accumulate before hiding the bar', (
    tester,
  ) async {
    final router = _router(_feedLikeScrollView());
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    final pointer = TestPointer(1, ui.PointerDeviceKind.mouse)
      ..hover(tester.getCenter(find.byKey(const Key('test-feed'))));
    for (var index = 0; index < 3; index++) {
      await tester.sendEventToBinding(
        pointer.scroll(const Offset(0, 8)),
      );
    }
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), 0);
  });

  testWidgets('metrics from an inactive short tab cannot reveal the bar', (
    tester,
  ) async {
    final router = _router(
      _feedLikeScrollView(),
      otherBranch: ListView(
        key: const Key('inactive-short-list'),
        children: const [SizedBox(height: 40)],
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    router.go(AppRoutes.feed);
    await tester.pumpAndSettle();
    router.go(AppRoutes.home);
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('test-feed')),
      const Offset(0, -40),
    );
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), 0);
  });

  testWidgets('short content keeps the bottom bar visible', (tester) async {
    final router = _router(_list(itemCount: 2));
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), greaterThan(0));
  });

  testWidgets('content near the overflow cutoff does not flicker back in', (
    tester,
  ) async {
    final router = _router(_list(itemCount: 14));
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -40));
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), 0);
  });

  testWidgets('reaching the end of long content reveals the bottom bar', (
    tester,
  ) async {
    final router = _router(_list(itemCount: 40));
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), 0);

    await tester.fling(
      find.byKey(const Key('test-list')),
      const Offset(0, -3000),
      5000,
    );
    await tester.pumpAndSettle();

    expect(_bottomBarHeight(tester), greaterThan(0));
  });

  testWidgets('reaching the top and refresh overscroll reveal the bottom bar', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    var refreshCount = 0;
    final router = _router(
      RefreshIndicator(
        onRefresh: () async => refreshCount++,
        child: _list(itemCount: 40, controller: scrollController),
      ),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), 0);

    scrollController.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), greaterThan(0));

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(refreshCount, 1);
    expect(_bottomBarHeight(tester), greaterThan(0));
  });

  testWidgets('keyboard restores the bar and suspends scroll reactions', (
    tester,
  ) async {
    final router = _router(_list(itemCount: 40));
    addTearDown(router.dispose);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -40));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), 0);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(_bottomBarHeight(tester), greaterThan(0));

    await tester.drag(find.byKey(const Key('test-list')), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(_bottomBarHeight(tester), greaterThan(0));
  });

  testWidgets('edge drag opens the drawer only at the navigation root', (
    tester,
  ) async {
    final router = _router(const SizedBox.expand());
    addTearDown(router.dispose);

    await tester.pumpWidget(_harness(router));
    await tester.pumpAndSettle();

    final shellScaffold = find.byWidgetPredicate(
      (widget) => widget is Scaffold && widget.drawer is SlideOutMenu,
    );
    Scaffold scaffold() => tester.widget<Scaffold>(shellScaffold);
    ScaffoldState scaffoldState() => tester.state<ScaffoldState>(
      shellScaffold,
    );

    expect(scaffold().drawerEnableOpenDragGesture, isTrue);
    await tester.dragFrom(const Offset(4, 300), const Offset(180, 0));
    await tester.pumpAndSettle();
    expect(scaffoldState().isDrawerOpen, isTrue);

    scaffoldState().closeDrawer();
    await tester.pumpAndSettle();
    unawaited(router.push<void>('${AppRoutes.home}/detail'));
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);
    expect(scaffold().drawerEnableOpenDragGesture, isFalse);
  });
}
