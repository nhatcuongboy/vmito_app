import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/domain/form/my_sessions_search_form.dart';

abstract interface class MySessionsSearchHistoryRepository {
  List<String> read(MySessionScope scope);
  Future<void> write(MySessionScope scope, List<String> queries);
}

class SharedPreferencesMySessionsSearchHistoryRepository
    implements MySessionsSearchHistoryRepository {
  const SharedPreferencesMySessionsSearchHistoryRepository(this._preferences);

  static const _keyPrefix = 'vmito.my_sessions.search_history.v1';
  final SharedPreferences _preferences;

  String _key(MySessionScope scope) => '$_keyPrefix.${scope.name}';

  @override
  List<String> read(MySessionScope scope) =>
      _preferences.getStringList(_key(scope)) ?? const [];

  @override
  Future<void> write(MySessionScope scope, List<String> queries) =>
      _preferences.setStringList(_key(scope), queries);
}

final mySessionsSearchHistoryRepositoryProvider =
    Provider<MySessionsSearchHistoryRepository>(
      (ref) => throw StateError(
        'My sessions search history must be configured',
      ),
    );

class MySessionsSearchHistoryController
    extends Notifier<Map<MySessionScope, List<String>>> {
  static const maxEntries = 10;

  MySessionsSearchHistoryRepository get _repository =>
      ref.read(mySessionsSearchHistoryRepositoryProvider);

  @override
  Map<MySessionScope, List<String>> build() => {
    for (final scope in MySessionScope.values) scope: _repository.read(scope),
  };

  Future<void> add(MySessionScope scope, String rawQuery) async {
    final query = normalizeMySessionsSearchQuery(rawQuery);
    if (query.isEmpty) return;
    final current = state[scope] ?? const [];
    final next = [
      query,
      ...current.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ].take(maxEntries).toList(growable: false);
    state = {...state, scope: next};
    await _repository.write(scope, next);
  }

  Future<void> remove(MySessionScope scope, String query) async {
    final next = (state[scope] ?? const [])
        .where((item) => item != query)
        .toList(growable: false);
    state = {...state, scope: next};
    await _repository.write(scope, next);
  }

  Future<void> clear(MySessionScope scope) async {
    state = {...state, scope: const []};
    await _repository.write(scope, const []);
  }
}

final mySessionsSearchHistoryProvider =
    NotifierProvider<
      MySessionsSearchHistoryController,
      Map<MySessionScope, List<String>>
    >(MySessionsSearchHistoryController.new);
