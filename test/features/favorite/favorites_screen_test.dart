import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/network/paginated.dart' as paginated;
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/app_error_view.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorites_screen.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/data/profile_tabs_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/social/domain/profile_tabs.dart';
import 'package:vmito_app/features/social/domain/social_post.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('renders favorite filters and empty state', (tester) async {
    await tester.pumpWidget(_app(_FakeProfileTabsService()));
    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Venues'), findsOneWidget);
    expect(find.text('Clubs'), findsOneWidget);
    expect(find.text('Tournaments'), findsOneWidget);
    expect(find.text('You have no favorites yet.'), findsOneWidget);
  });

  testWidgets('opens a saved session detail', (tester) async {
    await tester.pumpWidget(
      _app(_FakeProfileTabsService(withSavedSession: true)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Morning session'));
    await tester.pumpAndSettle();

    expect(find.text('Session detail'), findsOneWidget);
  });

  testWidgets('shows an error state when favorites cannot be loaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProfileTabsService(throwsState: true)));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
  });

  testWidgets('switches between favorite segments without checkmark icon', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_FakeProfileTabsService()));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<FavoriteType>>(
      find.byType(typeOf<SegmentedButton<FavoriteType>>()),
    );
    expect(segmentedButton.showSelectedIcon, isFalse);

    await tester.tap(find.text('Clubs'));
    await tester.pumpAndSettle();

    expect(find.text('You have no favorites yet.'), findsOneWidget);
  });

  testWidgets('loads the favorite type selected by the route', (tester) async {
    final service = _FakeProfileTabsService();
    await tester.pumpWidget(
      _app(service, initialType: FavoriteType.tournament),
    );
    await tester.pumpAndSettle();

    expect(service.requestedTypes, ['TOURNAMENT']);
    final segmentedButton = tester.widget<SegmentedButton<FavoriteType>>(
      find.byType(typeOf<SegmentedButton<FavoriteType>>()),
    );
    expect(segmentedButton.selected, {FavoriteType.tournament});
  });
}

Type typeOf<T>() => T;

Widget _app(
  ProfileTabsService service, {
  FavoriteType initialType = FavoriteType.session,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => FavoritesScreen(initialType: initialType),
      ),
      GoRoute(
        path: '/sessions/:id',
        builder: (_, _) => const Scaffold(body: Text('Session detail')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [profileTabsServiceProvider.overrideWithValue(service)],
    child: MaterialApp.router(
      locale: const Locale('en'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _FakeProfileTabsService implements ProfileTabsService {
  _FakeProfileTabsService({
    this.withSavedSession = false,
    this.throwsState = false,
  });

  final bool withSavedSession;
  final bool throwsState;
  final requestedTypes = <String>[];

  @override
  Future<paginated.Page<FavoriteTarget>> favorites(
    String type, {
    int page = 1,
  }) async {
    requestedTypes.add(type);
    if (throwsState) throw Exception('Failed to load favorites');
    return paginated.Page(
      items: withSavedSession && type == 'SESSION'
          ? const [FavoriteTarget(id: 'session-1', name: 'Morning session')]
          : const [],
      total: withSavedSession && type == 'SESSION' ? 1 : 0,
      page: page,
      limit: 10,
      totalPages: 1,
    );
  }

  @override
  Future<UserAchievements> achievements(String id) async =>
      throw UnimplementedError();

  @override
  Future<List<ClubSummary>> clubs(String id) async =>
      throw UnimplementedError();

  @override
  Future<paginated.Page<Session>> hosted(
    String id, {
    int page = 1,
    String filter = 'active',
  }) async => throw UnimplementedError();

  @override
  Future<SocialPostPage> posts(String id, {int page = 1}) async =>
      throw UnimplementedError();
}
