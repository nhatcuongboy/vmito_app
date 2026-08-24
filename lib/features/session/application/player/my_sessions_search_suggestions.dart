import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_list_query.dart';

// Kept as a boundary so widget tests can supply deterministic suggestions.
// ignore: one_member_abstracts
abstract interface class MySessionsSearchSuggestionService {
  Future<List<Session>> search({
    required MySessionScope scope,
    required String query,
  });
}

class ApiMySessionsSearchSuggestionService
    implements MySessionsSearchSuggestionService {
  const ApiMySessionsSearchSuggestionService(this._ref);

  static const _limit = 5;
  final Ref _ref;

  @override
  Future<List<Session>> search({
    required MySessionScope scope,
    required String query,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return const [];
    final listQuery = SessionListQuery(limit: _limit, search: query);
    final repository = _ref.read(sessionRepositoryProvider);
    final page = switch (scope) {
      MySessionScope.hosted => await repository.hostedBy(
        user.id,
        limit: _limit,
        query: listQuery,
      ),
      MySessionScope.joined => await repository.joinedByCurrentUser(listQuery),
    };
    return page.items;
  }
}

final mySessionsSearchSuggestionServiceProvider =
    Provider<MySessionsSearchSuggestionService>(
      ApiMySessionsSearchSuggestionService.new,
    );
