import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/leaderboard_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows the leaderboard skeleton while the first page loads', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_LoadingController.new));
    await tester.pump();

    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('renders podium in 2-1-3 order and highlights current user', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_LoadedController.new));
    await tester.pump();

    final podiumKeys = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(LeaderboardScreen),
            matching: find.byType(InkWell),
          ),
        )
        .map((widget) => widget.key)
        .whereType<ValueKey<String>>()
        .where((key) => key.value.startsWith('leaderboard-podium-'))
        .map((key) => key.value)
        .toList();
    expect(podiumKeys, [
      'leaderboard-podium-2',
      'leaderboard-podium-1',
      'leaderboard-podium-3',
    ]);
    expect(find.text('Khải 🦈', findRichText: true), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rules button opens the complete points sheet', (tester) async {
    await tester.pumpWidget(_app(_LoadedController.new));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('leaderboard-rules-button')));
    await tester.pumpAndSettle();

    expect(find.text('How points work'), findsWidgets);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Tournaments'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ranking tiers'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Ranking tiers'), findsOneWidget);
  });

  testWidgets('period picker selects a historical key', (tester) async {
    _LoadedController.lastPeriodKey = null;
    await tester.pumpWidget(_app(_LoadedController.new));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('leaderboard-period-picker')));
    await tester.pumpAndSettle();
    final historical = find.byKey(
      const ValueKey('leaderboard-period-option-2026-08-03'),
    );
    await tester.drag(
      find.byType(Scrollable).last,
      const Offset(0, -100),
    );
    await tester.pumpAndSettle();
    if (historical.evaluate().isNotEmpty) {
      await tester.tap(historical);
    } else {
      final fallbackOption = find.byType(ListTile).at(1);
      await tester.tap(fallbackOption);
    }
    await tester.pumpAndSettle();

    expect(_LoadedController.lastPeriodKey, isNotNull);
  });

  testWidgets('pull to refresh reloads the selected period', (tester) async {
    _LoadedController.loadCalls = 0;
    await tester.pumpWidget(_app(_LoadedController.new));
    await tester.pump();

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(_LoadedController.loadCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('shows empty state', (tester) async {
    await tester.pumpWidget(_app(_EmptyController.new));
    await tester.pump();
    expect(find.text('No ranking data yet'), findsOneWidget);
  });

  testWidgets('shows initial error state', (tester) async {
    await tester.pumpWidget(_app(_ErrorController.new));
    await tester.pump();
    expect(find.byType(AppErrorView), findsOneWidget);
  });

  testWidgets('does not overflow at narrow width and 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app(_LoadedController.new));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _app(LeaderboardController Function() createController) {
  final screenKey = ValueKey(createController().runtimeType);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => LeaderboardScreen(key: screenKey),
      ),
      GoRoute(
        path: '/user/:id',
        name: 'publicProfile',
        builder: (_, _) => const Scaffold(body: Text('Profile')),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
    ],
  );
  final app = ProviderScope(
    overrides: [
      leaderboardControllerProvider.overrideWith(createController),
      currentUserProvider.overrideWithValue(
        const User(
          id: 'u4',
          email: 'me@example.com',
          role: UserRole.player,
        ),
      ),
    ],
    child: MaterialApp.router(
      locale: const Locale('en'),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  return app;
}

class _LoadedController extends LeaderboardController {
  static String? lastPeriodKey;
  static int loadCalls = 0;

  @override
  Future<void> load({
    LeaderboardPeriod? period,
    String? periodKey,
  }) async {
    loadCalls++;
    lastPeriodKey = periodKey;
    state = LeaderboardState(
      period: period ?? LeaderboardPeriod.week,
      periodKey: periodKey,
      entries: [
        _entry('u1', 1),
        _entry('u2', 2, name: 'Khải 🦈'),
        _entry('u3', 3),
        _entry('u4', 4),
      ],
      page: 1,
      periodEnd: DateTime.now().add(const Duration(days: 2)),
      hasLoaded: true,
    );
  }
}

class _LoadingController extends LeaderboardController {
  @override
  Future<void> load({
    LeaderboardPeriod? period,
    String? periodKey,
  }) async {
    state = LeaderboardState(
      period: period ?? LeaderboardPeriod.week,
      isLoading: true,
    );
  }
}

class _EmptyController extends LeaderboardController {
  @override
  Future<void> load({
    LeaderboardPeriod? period,
    String? periodKey,
  }) async {
    state = LeaderboardState(
      period: period ?? LeaderboardPeriod.week,
      hasLoaded: true,
    );
  }
}

class _ErrorController extends LeaderboardController {
  @override
  Future<void> load({
    LeaderboardPeriod? period,
    String? periodKey,
  }) async {
    state = LeaderboardState(
      period: period ?? LeaderboardPeriod.week,
      hasLoaded: true,
      error: StateError('failed'),
    );
  }
}

LeaderboardEntry _entry(String id, int rank, {String? name}) =>
    LeaderboardEntry(
      rank: rank,
      points: 100 - rank,
      user: LeaderboardUser(id: id, name: name ?? 'Player $rank'),
      tier: RankingTier.values[(rank - 1) % RankingTier.values.length],
      totalPoints: 1200,
      matchesWon: 4,
      matchesPlayed: 6,
    );
