import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart' as pagination;
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/registration/application/my_join_requests_controller.dart';
import 'package:vmito_app/features/registration/data/registration_repository.dart';
import 'package:vmito_app/features/registration/domain/my_join_request.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';
import 'package:vmito_app/features/session/presentation/player/browse_sessions_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockRegistrationRepository extends Mock
    implements RegistrationRepository {}

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

void _stubMyJoinRequests(_MockRegistrationRepository repository) {
  when(
    () => repository.myJoinRequests(
      page: any(named: 'page'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) async => _page(<MyJoinRequest>[]));
}

Future<void> _pump(
  WidgetTester tester,
  SessionRepository repository,
) async {
  final registrationRepository = _MockRegistrationRepository();
  _stubMyJoinRequests(registrationRepository);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_me),
        isSignedInProvider.overrideWithValue(true),
        sessionRepositoryProvider.overrideWithValue(repository),
        registrationRepositoryProvider.overrideWithValue(
          registrationRepository,
        ),
        mySessionsRealtimeProvider.overrideWith((ref) {}),
        myJoinRequestsRealtimeProvider.overrideWith((ref) {}),
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
  SessionRepository repository, {
  void Function(_MockRegistrationRepository registrationRepository)?
  configureRegistration,
}) async {
  final registrationRepository = _MockRegistrationRepository();
  _stubMyJoinRequests(registrationRepository);
  configureRegistration?.call(registrationRepository);
  final router = GoRouter(
    initialLocation: '/sessions',
    routes: [
      GoRoute(
        path: '/sessions',
        builder: (_, _) => const BrowseSessionsScreen(),
        routes: [
          GoRoute(
            path: 'search',
            builder: (context, state) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: const Key('fake-my-sessions-search-submit'),
                  onPressed: () => context.pop('kèo tối'),
                  child: Text(state.uri.queryParameters['scope'] ?? ''),
                ),
              ),
            ),
          ),
          GoRoute(
            path: ':id',
            builder: (_, state) => Text('detail-${state.pathParameters['id']}'),
            routes: [
              GoRoute(
                path: 'manage',
                builder: (_, state) =>
                    Text('manage-${state.pathParameters['id']}'),
              ),
              GoRoute(
                path: 'live',
                builder: (_, state) =>
                    Text('live-${state.pathParameters['id']}'),
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
        isSignedInProvider.overrideWithValue(true),
        sessionRepositoryProvider.overrideWithValue(repository),
        registrationRepositoryProvider.overrideWithValue(
          registrationRepository,
        ),
        mySessionsRealtimeProvider.overrideWith((ref) {}),
        myJoinRequestsRealtimeProvider.overrideWith((ref) {}),
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

  testWidgets('renders the fixed sort/filter toolbar and keeps scope state', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    await _pump(tester, repository);

    expect(find.text('Quản lý kèo'), findsOneWidget);
    expect(find.text('Kèo tham gia'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('my-sessions-scope'))).height,
      kTextTabBarHeight,
    );
    expect(find.byType(SearchBar), findsNothing);
    expect(find.byKey(const Key('my-sessions-search-button')), findsOneWidget);
    expect(find.byKey(const Key('my-sessions-filter-button')), findsOneWidget);
    expect(find.byKey(const Key('my-sessions-sort-button')), findsOneWidget);
    expect(find.text('Gần nhất'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('my-sessions-sort-button'))).dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const Key('my-sessions-scope'))).dy,
      ),
    );

    await tester.tap(find.byKey(const Key('my-sessions-sort-button')));
    await tester.pumpAndSettle();
    expect(find.text('Xa nhất'), findsOneWidget);
    expect(find.text('Mới đăng'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('my-sessions-sort-dateFurthest')),
    );
    await tester.pumpAndSettle();

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
    expect(find.text('Gần nhất'), findsOneWidget);

    // Pending requests button should only be visible in Quản lý kèo scope
    expect(find.byKey(const Key('pending-requests-button')), findsNothing);
    expect(find.byKey(const Key('my-join-requests-button')), findsOneWidget);
    expect(find.byKey(const Key('my-sessions-create-fab')), findsNothing);

    // Open filter sheet and select all
    await tester.tap(find.byKey(const Key('my-sessions-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('my-sessions-filter-all')));
    await tester.pumpAndSettle();

    // Switch back to Quản lý kèo
    await tester.tap(find.text('Quản lý kèo'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pending-requests-button')), findsOneWidget);
    expect(find.byKey(const Key('my-sessions-create-fab')), findsOneWidget);
    expect(find.text('Xa nhất'), findsOneWidget);

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
    expect(
      scope.read(mySessionsControllerProvider(MySessionScope.hosted)).sort,
      MySessionSort.dateFurthest,
    );
    expect(
      scope.read(mySessionsControllerProvider(MySessionScope.joined)).sort,
      MySessionSort.dateNearest,
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
    expect(find.byIcon(AppIcons.clipboardList), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('searches the active scope and back restores its snapshot', (
    tester,
  ) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.byKey(const Key('my-sessions-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('hosted'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('fake-my-sessions-search-submit')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('my-sessions-search-result-query')),
      findsOneWidget,
    );
    expect(find.text('kèo tối'), findsOneWidget);
    final searchedQuery =
        verify(
              () => repository.hostedBy(
                any(),
                limit: any(named: 'limit'),
                page: any(named: 'page'),
                query: captureAny(named: 'query'),
              ),
            ).captured.last
            as SessionListQuery;
    expect(searchedQuery.search, 'kèo tối');

    await tester.tap(
      find.byKey(const Key('my-sessions-search-exit-results')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('my-sessions-search-result-query')),
      findsNothing,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(BrowseSessionsScreen)),
    );
    expect(
      container
          .read(mySessionsControllerProvider(MySessionScope.hosted))
          .search,
      isEmpty,
    );
  });

  testWidgets('opens search with the joined scope', (tester) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.text('Kèo tham gia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('my-sessions-search-button')));
    await tester.pumpAndSettle();

    expect(find.text('joined'), findsOneWidget);
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
          hostName: 'Chủ kèo',
          status: SessionStatus.preparing,
        ),
      ]),
    );
    await _pumpWithRouter(tester, repository);

    expect(find.byKey(const Key('session-host-name')), findsNothing);
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

    expect(find.text('Sắp diễn ra'), findsOneWidget);
    expect(find.byKey(const Key('session-sport-badge')), findsNothing);
    final card = tester.getTopLeft(find.byType(Card));
    final sessionStatus = tester.getTopLeft(
      find.byKey(const Key('session-status-badge')),
    );
    expect(sessionStatus.dy, closeTo(card.dy + AppSpacing.xs, 0.01));

    await tester.tap(find.byKey(const ValueKey('session-host-button-h1')));
    await tester.pumpAndSettle();

    expect(find.text('manage-h1'), findsOneWidget);
  });

  testWidgets(
    'joined card opens detail with its status at the bottom of the cover',
    (
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
      final sessionStatus = tester.getTopLeft(
        find.byKey(const Key('session-status-badge')),
      );
      final registrationStatus = tester.getTopLeft(
        find.byKey(const Key('session-registration-status-badge')),
      );
      expect(find.text('Sắp diễn ra'), findsOneWidget);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.byKey(const Key('session-sport-badge')), findsNothing);
      expect(
        find.byKey(const Key('session-registration-sport-icon')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('session-registration-status-badge')),
          matching: find.byIcon(AppIcons.clock),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('session-slots-badge')), findsNothing);
      expect(registrationStatus.dy, lessThan(sessionStatus.dy));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('session-primary-button-j1')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Joined one'));
      await tester.pumpAndSettle();

      expect(find.text('detail-j1'), findsOneWidget);
    },
  );

  testWidgets('joined card enters the correct court board', (tester) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(() => repository.joinedByCurrentUser(any())).thenAnswer(
      (_) async => _page([
        const Session(
          id: 'j1',
          name: 'Joined one',
          status: SessionStatus.preparing,
        ),
      ]),
    );
    await _pumpWithRouter(tester, repository);

    await tester.tap(find.text('Kèo tham gia'));
    await tester.pumpAndSettle();
    expect(find.text('Vào sân'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('session-more-button-j1')));
    await tester.pumpAndSettle();
    expect(find.text('Xem vé'), findsOneWidget);
    expect(find.text('Thêm khách'), findsOneWidget);
    expect(find.text('Chia sẻ'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-primary-button-j1')));
    await tester.pumpAndSettle();

    expect(find.text('live-j1'), findsOneWidget);
  });

  testWidgets('joined card opens the selected session ticket', (tester) async {
    final repository = _MockSessionRepository();
    _stubSessionLists(repository);
    when(() => repository.joinedByCurrentUser(any())).thenAnswer(
      (_) async => _page([
        const Session(
          id: 'j1',
          name: 'Joined one',
          status: SessionStatus.preparing,
        ),
      ]),
    );
    late _MockRegistrationRepository registrationRepository;
    await _pumpWithRouter(
      tester,
      repository,
      configureRegistration: (repository) {
        registrationRepository = repository;
        when(() => repository.myPlayers('j1')).thenAnswer(
          (_) async => [const SessionPlayer(id: 'ticket-j1', name: 'Vé j1')],
        );
      },
    );

    await tester.tap(find.text('Kèo tham gia'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('session-more-button-j1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem vé'));
    await tester.pumpAndSettle();

    expect(find.text('Vé j1'), findsOneWidget);
    verify(() => registrationRepository.myPlayers('j1')).called(1);
  });
}
