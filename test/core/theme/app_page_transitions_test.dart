import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/theme/app_theme.dart';

void main() {
  for (final platform in TargetPlatform.values) {
    testWidgets('edge back takes priority over tabs on $platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light.copyWith(platform: platform),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const DefaultTabController(
                        length: 2,
                        child: Scaffold(
                          key: Key('second-page'),
                          body: TabBarView(
                            children: [Text('Overview'), Text('Players')],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.dragFrom(const Offset(600, 300), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Players').hitTestable(), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(160, 0));
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(const Key('second-page'))).dx,
        closeTo(160, 0.01),
      );

      await gesture.moveBy(const Offset(300, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('second-page')), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  }

  for (final detailPath in ['/sessions/s1', '/venues/v1', '/clubs/c1']) {
    testWidgets('edge back works for GoRouter detail $detailPath', (
      tester,
    ) async {
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final router = GoRouter(
        navigatorKey: rootNavigatorKey,
        initialLocation: '/sessions',
        routes: [
          GoRoute(
            path: '/venues',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, _) => const Scaffold(body: Text('Venues')),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, _) => _detailPage(detailPath),
              ),
            ],
          ),
          GoRoute(
            path: '/clubs',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, _) => const Scaffold(body: Text('Clubs')),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, _) => _detailPage(detailPath),
              ),
            ],
          ),
          StatefulShellRoute.indexedStack(
            builder: (_, _, navigationShell) => navigationShell,
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/sessions',
                    builder: (_, _) => const Scaffold(body: Text('Sessions')),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (_, _) => _detailPage(detailPath),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      );
      await tester.pumpAndSettle();

      unawaited(router.push<void>(detailPath));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);
      final detailRoute = ModalRoute.of(
        tester.element(find.byKey(ValueKey(detailPath))),
      )!;
      expect(detailRoute.isFirst, isFalse);
      expect(detailRoute.willHandlePopInternally, isFalse);
      expect(detailRoute.popDisposition, RoutePopDisposition.pop);
      expect(detailRoute.animation!.isCompleted, isTrue);
      expect(detailRoute.popGestureEnabled, isTrue);
      expect(detailRoute.settings, isA<MaterialPage<void>>());
      expect(find.byType(CupertinoPageTransition), findsWidgets);

      final gesture = await tester.startGesture(const Offset(2, 300));
      await gesture.moveBy(const Offset(160, 0));
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(ValueKey(detailPath))).dx,
        closeTo(160, 0.01),
      );

      await gesture.moveBy(const Offset(300, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey(detailPath)), findsNothing);
    });
  }
}

Widget _detailPage(String path) => DefaultTabController(
  length: 2,
  child: Scaffold(
    key: ValueKey(path),
    body: const TabBarView(children: [Text('Overview'), Text('Players')]),
  ),
);
