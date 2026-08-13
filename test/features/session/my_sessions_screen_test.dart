import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';
import 'package:vmito_app/features/session/presentation/player/browse_sessions_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

const _me = User(id: 'u1', email: 'me@vmito.com', role: UserRole.host);

pagination.Page<T> _page<T>(List<T> items) => pagination.Page(
  items: items,
  total: items.length,
  page: 1,
  limit: 20,
  totalPages: 1,
);

void _stubSessionLists(_MockSessionRepository repository) {
  when(
    () => repository.hostedBy(
      any(),
      limit: any(named: 'limit'),
      page: any(named: 'page'),
      query: any(named: 'query'),
    ),
  ).thenAnswer((_) async => _page(<Session>[]));
  when(
    () => repository.joinedByCurrentUser(any()),
  ).thenAnswer((_) async => _page(<Session>[]));
  when(repository.pendingJoinRequestCount).thenAnswer((_) async => 0);
}

Future<void> _pump(
  WidgetTester tester,
  SessionRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        sessionRepositoryProvider.overrideWithValue(repository),
        mySessionsRealtimeProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const BrowseSessionsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpWithRouter(
  WidgetTester tester,
  SessionRepository repository,
) async {
  final router = GoRouter(
    initialLocation: '/sessions',
    routes: [
      GoRoute(
        path: '/sessions',
        builder: (_, _) => const BrowseSessionsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => Text('detail-${state.pathParameters['id']}'),
            routes: [
              GoRoute(
                path: 'manage',
                builder: (_, state) =>
                    Text('manage-${state.pathParameters['id']}'),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        sessionRepositoryProvider.overrideWithValue(repository),
        mySessionsRealtimeProvider.overrideWith((ref) {}),
      ],
      child: MaterialApp.router(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => registerFallbackValue(const SessionListQuery()));

  testWidgets('defaults to Quản lý kèo / Đang mở and keeps scope state', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    await _pump(tester, repository);

    expect(find.text('Quản lý kèo'), findsOneWidget);
    expect(find.text('Kèo tham gia'), findsOneWidget);

    // Open filter sheet and select ended
    await tester.tap(find.byKey(const Key('my-sessions-filter-button')));
    await tester.pumpAndSettle();
    expect(find.text('Đang mở'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('my-sessions-filter-ended')),
    );
    await tester.pumpAndSettle();

    // Switch to Kèo tham gia tab
    await tester.tap(find.text('Kèo tham gia'));
    await tester.pumpAndSettle();

    // Pending requests button should only be visible in Quản lý kèo scope
    expect(find.byKey(const Key('pending-requests-button')), findsNothing);

    // Open filter sheet and select all
    await tester.tap(find.byKey(const Key('my-sessions-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my-sessions-filter-all')));
    await tester.pumpAndSettle();

    // Switch back to Quản lý kèo
    await tester.tap(find.text('Quản lý kèo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pending-requests-button')), findsOneWidget);

    final scope = ProviderScope.containerOf(
      tester.element(find.byType(BrowseSessionsScreen)),
    );
    expect(
      scope.read(mySessionsControllerProvider(MySessionScope.hosted)).filter,
      MySessionFilter.ended,
    );
    expect(
      scope.read(mySessionsControllerProvider(MySessionScope.joined)).filter,
      MySessionFilter.all,
    );
  });

  testWidgets('shows pending requests badge on AppBar', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(repository.pendingJoinRequestCount).thenAnswer((_) async => 1);
    await _pump(tester, repository);

    expect(find.byKey(const Key('pending-requests-button')), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('hosted card opens detail', (tester) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => _page([
        const Session(
          id: 'h1',
          name: 'Hosted one',
          status: SessionStatus.preparing,
        ),
      ]),
    );
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.text('Hosted one'));
    await tester.pumpAndSettle();

    expect(find.text('detail-h1'), findsOneWidget);
  });

  testWidgets('host button on hosted card opens manage', (tester) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    ).thenAnswer(
      (_) async => _page([
        const Session(
          id: 'h1',
          name: 'Hosted one',
          status: SessionStatus.preparing,
        ),
      ]),
    );
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.byKey(const ValueKey('session-host-button-h1')));
    await tester.pumpAndSettle();

    expect(find.text('manage-h1'), findsOneWidget);
  });

  testWidgets('joined card opens detail and marks pending registration', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(() => repository.joinedByCurrentUser(any())).thenAnswer(
      (_) async => _page([
        const Session(
          id: 'j1',
          name: 'Joined one',
          status: SessionStatus.preparing,
          players: [
            SessionPlayer(
              id: 'p1',
              registrationStatus: RegistrationStatus.pending,
            ),
          ],
        ),
      ]),
    );
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.text('Kèo tham gia'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('joined-session-pending-badge')),
      findsOneWidget,
    );
    await tester.tap(find.text('Joined one'));
    await tester.pumpAndSettle();

    expect(find.text('detail-j1'), findsOneWidget);
  });
}
