import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/registration/domain/pending_join_request.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

const _me = User(id: 'u1', email: 'me@vmito.com', role: UserRole.host);

Page<T> _page<T>(
  List<T> items, {
  int page = 1,
  int totalPages = 1,
}) => Page(
  items: items,
  total: items.length,
  page: page,
  limit: 20,
  totalPages: totalPages,
);

Session _session(String id) => Session(
  id: id,
  name: 'Session $id',
  status: SessionStatus.preparing,
);

ProviderContainer _container(SessionRepository repository) {
  final container = ProviderContainer(
    overrides: [
      currentUserProvider.overrideWithValue(_me),
      sessionRepositoryProvider.overrideWithValue(repository),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const SessionListQuery());
  });

  test('hosted active/ended/all produce the web-equivalent queries', () async {
    final repository = _MockSessionRepository();
    when(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => _page([_session('h1')]));
    when(repository.pendingJoinRequestCount).thenAnswer((_) async => 3);
    final container = _container(repository);
    final controller = container.read(
      mySessionsControllerProvider(MySessionScope.hosted).notifier,
    );

    await controller.loadInitial();
    var query =
        verify(
              () => repository.hostedBy(
                'u1',
                limit: 20,
                query: captureAny(named: 'query'),
              ),
            ).captured.single
            as SessionListQuery;
    expect(
      query.excludedStatuses,
      [SessionStatus.finished, SessionStatus.cancelled],
    );

    await controller.setFilter(MySessionFilter.ended);
    query =
        verify(
              () => repository.hostedBy(
                'u1',
                limit: 20,
                query: captureAny(named: 'query'),
              ),
            ).captured.single
            as SessionListQuery;
    expect(query.status, SessionStatus.finished);
    expect(query.excludedStatuses, isEmpty);

    await controller.setFilter(MySessionFilter.all);
    await controller.setSearch('  sân A  ');
    query =
        verify(
              () => repository.hostedBy(
                'u1',
                limit: 20,
                query: captureAny(named: 'query'),
              ),
            ).captured.last
            as SessionListQuery;
    expect(query.status, isNull);
    expect(query.excludedStatuses, isEmpty);
    expect(query.search, 'sân A');
  });

  test(
    'joined uses its endpoint contract and deduplicates load-more',
    () async {
      final repository = _MockSessionRepository();
      when(() => repository.joinedByCurrentUser(any())).thenAnswer((
        invocation,
      ) async {
        final query = invocation.positionalArguments.single as SessionListQuery;
        return query.page == 1
            ? _page([_session('j1'), _session('shared')], totalPages: 2)
            : _page(
                [_session('shared'), _session('j2')],
                page: 2,
                totalPages: 2,
              );
      });
      final container = _container(repository);
      final controller = container.read(
        mySessionsControllerProvider(MySessionScope.joined).notifier,
      );

      await controller.loadInitial();
      await controller.loadMore();

      final state = container.read(
        mySessionsControllerProvider(MySessionScope.joined),
      );
      expect(state.sessions.map((session) => session.id), [
        'j1',
        'shared',
        'j2',
      ]);
      final firstQuery =
          verify(
                () => repository.joinedByCurrentUser(captureAny()),
              ).captured.first
              as SessionListQuery;
      expect(firstQuery.excludedStatuses, contains(SessionStatus.cancelled));
    },
  );

  test(
    'pending approve updates registration then refreshes list and count',
    () async {
      final repository = _MockSessionRepository();
      const request = PendingJoinRequest(
        id: 'p1',
        sessionId: 's1',
        sessionName: 'Kèo tối',
        playerName: 'An',
      );
      var requestLoads = 0;
      when(
        () => repository.pendingJoinRequests(
          page: any(named: 'page'),
          limit: any(named: 'limit'),
          search: any(named: 'search'),
        ),
      ).thenAnswer((_) async {
        requestLoads++;
        return _page(requestLoads == 1 ? [request] : []);
      });
      when(repository.pendingJoinRequestCount).thenAnswer(
        (_) async => requestLoads == 1 ? 1 : 0,
      );
      when(
        () => repository.updateRegistration(
          any(),
          any(),
          approved: any(named: 'approved'),
        ),
      ).thenAnswer((_) async {});
      final container = _container(repository);
      final controller = container.read(
        mySessionsControllerProvider(MySessionScope.hosted).notifier,
      );

      await controller.setFilter(MySessionFilter.pending);
      await controller.decideRequest(request, approved: true);

      verify(
        () => repository.updateRegistration('s1', 'p1', approved: true),
      ).called(1);
      final state = container.read(
        mySessionsControllerProvider(MySessionScope.hosted),
      );
      expect(state.pendingRequests, isEmpty);
      expect(state.pendingCount, 0);
    },
  );

  test(
    'hosted and joined keep independent filter, sort, and search state',
    () async {
      final repository = _MockSessionRepository();
      when(
        () => repository.hostedBy(
          any(),
          limit: any(named: 'limit'),
          page: any(named: 'page'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => _page(<Session>[]));
      when(() => repository.joinedByCurrentUser(any())).thenAnswer(
        (_) async => _page(<Session>[]),
      );
      when(repository.pendingJoinRequestCount).thenAnswer((_) async => 0);
      final container = _container(repository);
      final hosted = container.read(
        mySessionsControllerProvider(MySessionScope.hosted).notifier,
      );
      final joined = container.read(
        mySessionsControllerProvider(MySessionScope.joined).notifier,
      );

      await hosted.setFilter(MySessionFilter.ended);
      await hosted.setSort(MySessionSort.dateFurthest);
      await hosted.setSearch('hosted');
      await joined.setFilter(MySessionFilter.all);
      await joined.setSort(MySessionSort.newest);
      await joined.setSearch('joined');

      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.hosted))
            .filter,
        MySessionFilter.ended,
      );
      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.hosted))
            .search,
        'hosted',
      );
      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.hosted))
            .sort,
        MySessionSort.dateFurthest,
      );
      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.joined))
            .filter,
        MySessionFilter.all,
      );
      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.joined))
            .search,
        'joined',
      );
      expect(
        container
            .read(mySessionsControllerProvider(MySessionScope.joined))
            .sort,
        MySessionSort.newest,
      );
    },
  );

  test('sort reloads sessions with the selected backend ordering', () async {
    final repository = _MockSessionRepository();
    when(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) async => _page(<Session>[]));
    when(repository.pendingJoinRequestCount).thenAnswer((_) async => 0);
    final container = _container(repository);
    final controller = container.read(
      mySessionsControllerProvider(MySessionScope.hosted).notifier,
    );

    await controller.loadInitial();
    await controller.setSort(MySessionSort.dateFurthest);
    await controller.setSort(MySessionSort.newest);

    final queries = verify(
      () => repository.hostedBy(
        'u1',
        limit: 20,
        query: captureAny(named: 'query'),
      ),
    ).captured.cast<SessionListQuery>();
    expect(queries[0].sortBy, 'date');
    expect(queries[0].sortOrder, 'asc');
    expect(queries[1].sortBy, 'date');
    expect(queries[1].sortOrder, 'desc');
    expect(queries[2].sortBy, 'created');
    expect(queries[2].sortOrder, 'desc');
  });

  test('restore invalidates an in-flight search response', () async {
    final repository = _MockSessionRepository();
    final response = Completer<Page<Session>>();
    when(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    ).thenAnswer((_) => response.future);
    when(repository.pendingJoinRequestCount).thenAnswer((_) async => 0);
    final container = _container(repository);
    final controller = container.read(
      mySessionsControllerProvider(MySessionScope.hosted).notifier,
    );
    final snapshot = MySessionsState(
      sessions: [_session('original')],
      hasLoaded: true,
    );

    final search = controller.setSearch('new query');
    controller.restore(snapshot);
    response.complete(_page([_session('late')]));
    await search;

    final state = container.read(
      mySessionsControllerProvider(MySessionScope.hosted),
    );
    expect(state.search, isEmpty);
    expect(state.sessions.single.id, 'original');
  });

  test('load failure is retained for the retry/error state', () async {
    final repository = _MockSessionRepository();
    when(
      () => repository.joinedByCurrentUser(any()),
    ).thenThrow(StateError('network'));
    final container = _container(repository);
    final controller = container.read(
      mySessionsControllerProvider(MySessionScope.joined).notifier,
    );

    await controller.loadInitial();

    final state = container.read(
      mySessionsControllerProvider(MySessionScope.joined),
    );
    expect(state.hasLoaded, isTrue);
    expect(state.isLoading, isFalse);
    expect(state.error, isA<StateError>());
  });
}
