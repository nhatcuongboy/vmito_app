import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/auth/domain/user.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_suggestions.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';

class _MockSessionRepository extends Mock implements SessionRepository {}

const _me = User(id: 'u1', email: 'me@vmito.com', role: UserRole.host);

void main() {
  setUpAll(() => registerFallbackValue(const SessionListQuery()));

  test(
    'hosted suggestions use the current host and a five-item query',
    () async {
      final repository = _MockSessionRepository();
      when(
        () => repository.hostedBy(
          any(),
          limit: any(named: 'limit'),
          page: any(named: 'page'),
          query: any(named: 'query'),
        ),
      ).thenAnswer((_) async => _page());
      final container = _container(repository);

      await container
          .read(mySessionsSearchSuggestionServiceProvider)
          .search(scope: MySessionScope.hosted, query: 'kèo tối');

      final captured =
          verify(
                () => repository.hostedBy(
                  'u1',
                  limit: 5,
                  query: captureAny(named: 'query'),
                ),
              ).captured.single
              as SessionListQuery;
      expect(captured.limit, 5);
      expect(captured.search, 'kèo tối');
    },
  );

  test('joined suggestions use only the joined endpoint', () async {
    final repository = _MockSessionRepository();
    when(
      () => repository.joinedByCurrentUser(any()),
    ).thenAnswer((_) async => _page());
    final container = _container(repository);

    await container
        .read(mySessionsSearchSuggestionServiceProvider)
        .search(scope: MySessionScope.joined, query: 'sân A');

    final captured =
        verify(
              () => repository.joinedByCurrentUser(captureAny()),
            ).captured.single
            as SessionListQuery;
    expect(captured.limit, 5);
    expect(captured.search, 'sân A');
    verifyNever(
      () => repository.hostedBy(
        any(),
        limit: any(named: 'limit'),
        page: any(named: 'page'),
        query: any(named: 'query'),
      ),
    );
  });
}

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

Page<Session> _page() => const Page(
  items: [],
  total: 0,
  page: 1,
  limit: 5,
  totalPages: 1,
);
