import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/router/app_routes.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/application/achievement_share_service.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/public_profile.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/features/social/presentation/widgets/user_achievements_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _profile = PublicProfile(
  id: 'user-123456789',
  name: 'Nguyen Player',
  role: 'PLAYER',
  joinedSessionsCount: 4,
);

final _achievements = UserAchievements(
  totalPoints: 1750,
  tier: RankingTier.gold,
  nextTier: const NextTier(
    tier: RankingTier.platinum,
    pointsToNext: 2250,
  ),
  ranks: const [
    UserRank(period: 'week', rank: 3, points: 90),
    UserRank(period: 'month', rank: 6, points: 210),
    UserRank(period: 'year', rank: null, points: 400),
  ],
  stats: const UserAchievementStats(
    wins: 8,
    draws: 2,
    losses: 4,
    matchesPlayed: 14,
    tournamentTitles: 2,
    tournamentRunnerUps: 1,
  ),
  recentTransactions: [
    for (var index = 0; index < 25; index++)
      PointTransaction(
        id: 'tx-$index',
        points: index.isEven ? 10 : -2,
        reason: index == 0 ? 'SESSION_MATCH_WIN' : 'FUTURE_REASON',
        occurredAt: DateTime(2026, 8, 20),
      ),
  ],
);

void main() {
  testWidgets('shows a loading indicator while achievements are pending', (
    tester,
  ) async {
    await _pump(
      tester,
      service: _PendingService(),
      isOwner: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders ported content and caps point history at 20', (
    tester,
  ) async {
    await _pump(tester, service: _FakeService(_achievements), isOwner: true);
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.text('Nguyen Player'), findsOneWidget);
    expect(find.text('1750'), findsOneWidget);
    expect(find.text('Gold'), findsOneWidget);
    expect(find.text('Rank 3'), findsOneWidget);
    expect(find.text('—'), findsWidgets);
    expect(find.text('Win a session match'), findsOneWidget);
    expect(find.text('Future reason'), findsNWidgets(19));
    expect(
      find.byKey(const ValueKey('achievement-share-card-button')),
      findsOneWidget,
    );
  });

  testWidgets('hides share action for a profile visitor', (tester) async {
    await _pump(tester, service: _FakeService(_achievements), isOwner: false);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('achievement-share-card-button')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('achievement-view-leaderboard-button')),
      findsOneWidget,
    );
  });

  testWidgets('uses two rank columns on mobile and four on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, service: _FakeService(_achievements), isOwner: false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('achievement-rank-grid-2')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(800, 1000);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester, service: _FakeService(_achievements), isOwner: false);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('achievement-rank-grid-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows empty history and opens the points rules sheet', (
    tester,
  ) async {
    const empty = UserAchievements(
      totalPoints: 0,
      tier: RankingTier.bronze,
      ranks: [],
      stats: UserAchievementStats(),
      recentTransactions: [],
    );
    await _pump(tester, service: _FakeService(empty), isOwner: false);
    await tester.pump();

    await tester.ensureVisible(
      find.byKey(const ValueKey('achievement-rules-button')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No points yet'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('achievement-rules-button')));
    await tester.pumpAndSettle();
    expect(find.text('How points work'), findsWidgets);
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets('retries after a load error', (tester) async {
    final service = _RetryService(_achievements);
    await _pump(tester, service: service, isOwner: false);
    await tester.pump();

    expect(find.text('Failed to load achievements'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));

    expect(find.byKey(const ValueKey('achievement-hero')), findsOneWidget);
    expect(service.calls, 2);
  });

  testWidgets('pull to refresh reloads achievements', (tester) async {
    final service = _FakeService(_achievements);
    await _pump(tester, service: service, isOwner: false);
    await tester.pump();

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(service.calls, greaterThanOrEqualTo(2));
  });

  testWidgets('switches to the leaderboard route', (tester) async {
    final router = await _pump(
      tester,
      service: _FakeService(_achievements),
      isOwner: false,
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('achievement-view-leaderboard-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('achievement-view-leaderboard-button')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard route'), findsOneWidget);
    expect(router.state.uri.path, AppRoutes.leaderboard);
    expect(
      router.routerDelegate.currentConfiguration.matches.last,
      isNot(isA<ImperativeRouteMatch>()),
    );
  });

  testWidgets('captures and shares the achievement PNG', (tester) async {
    final capture = _FakeCaptureService();
    final share = _FakeShareService();
    await _pump(
      tester,
      service: _FakeService(_achievements),
      isOwner: true,
      capture: capture,
      share: share,
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('achievement-share-card-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('achievement-share-card-button')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('achievement-share-card-preview')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('achievement-share-image-button')),
    );
    await tester.pumpAndSettle();

    expect(capture.calls, 1);
    expect(share.fileName, 'ThanhTich-user-123.png');
    expect(share.bytes, Uint8List.fromList([1, 2, 3]));
  });
}

Future<GoRouter> _pump(
  WidgetTester tester, {
  required ProfileTabsService service,
  required bool isOwner,
  AchievementCaptureService? capture,
  AchievementShareService? share,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: UserAchievementsTab(
            userId: _profile.id,
            profile: _profile,
            isOwner: isOwner,
          ),
        ),
      ),
      GoRoute(
        path: '/leaderboard',
        name: AppRoutes.nameLeaderboard,
        builder: (_, _) => const Scaffold(body: Text('Leaderboard route')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileTabsServiceProvider.overrideWithValue(service),
        if (capture != null)
          achievementCaptureServiceProvider.overrideWithValue(capture),
        if (share != null)
          achievementShareServiceProvider.overrideWithValue(share),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  return router;
}

class _FakeService implements ProfileTabsService {
  _FakeService(this.value);

  final UserAchievements value;
  int calls = 0;

  @override
  Future<UserAchievements> achievements(String id) async {
    calls++;
    return value;
  }

  @override
  Future<List<ClubSummary>> clubs(String id) => throw UnimplementedError();

  @override
  Future<pagination.Page<FavoriteTarget>> favorites(
    String type, {
    int page = 1,
  }) => throw UnimplementedError();

  @override
  Future<pagination.Page<Session>> hosted(
    String id, {
    int page = 1,
    String filter = 'active',
  }) => throw UnimplementedError();

  @override
  Future<SocialPostPage> posts(String id, {int page = 1}) =>
      throw UnimplementedError();
}

class _PendingService extends _FakeService {
  _PendingService() : super(_achievements);

  final Completer<UserAchievements> completer = Completer<UserAchievements>();

  @override
  Future<UserAchievements> achievements(String id) => completer.future;
}

class _RetryService extends _FakeService {
  _RetryService(super.value);

  @override
  Future<UserAchievements> achievements(String id) async {
    calls++;
    if (calls == 1) throw StateError('initial failure');
    return value;
  }
}

class _FakeCaptureService implements AchievementCaptureService {
  int calls = 0;

  @override
  Future<Uint8List?> capture(RenderRepaintBoundary boundary) async {
    calls++;
    return Uint8List.fromList([1, 2, 3]);
  }
}

class _FakeShareService implements AchievementShareService {
  Uint8List? bytes;
  String? fileName;

  @override
  Future<void> sharePng(
    Uint8List bytes, {
    required String fileName,
    Rect? origin,
  }) async {
    this.bytes = bytes;
    this.fileName = fileName;
  }
}
