import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

abstract interface class HomeSearchHistoryRepository {
  List<String> read(HomeDiscoveryTab tab);
  Future<void> write(HomeDiscoveryTab tab, List<String> queries);
}

class SharedPreferencesHomeSearchHistoryRepository
    implements HomeSearchHistoryRepository {
  const SharedPreferencesHomeSearchHistoryRepository(this._preferences);

  static const _keyPrefix = 'vmito.home.search_history.v1';
  final SharedPreferences _preferences;

  String _key(HomeDiscoveryTab tab) => '$_keyPrefix.${tab.name}';

  @override
  List<String> read(HomeDiscoveryTab tab) =>
      _preferences.getStringList(_key(tab)) ?? const [];

  @override
  Future<void> write(HomeDiscoveryTab tab, List<String> queries) =>
      _preferences.setStringList(_key(tab), queries);
}

final homeSearchHistoryRepositoryProvider =
    Provider<HomeSearchHistoryRepository>(
      (ref) => throw StateError('Home search history must be configured'),
    );

class HomeSearchHistoryController
    extends Notifier<Map<HomeDiscoveryTab, List<String>>> {
  static const maxEntries = 10;

  HomeSearchHistoryRepository get _repository =>
      ref.read(homeSearchHistoryRepositoryProvider);

  @override
  Map<HomeDiscoveryTab, List<String>> build() => {
    for (final tab in HomeDiscoveryTab.values) tab: _repository.read(tab),
  };

  Future<void> add(HomeDiscoveryTab tab, String rawQuery) async {
    final query = normalizeSearchQuery(rawQuery);
    if (query.isEmpty) return;
    final current = state[tab] ?? const [];
    final next = [
      query,
      ...current.where(
        (item) => item.toLowerCase() != query.toLowerCase(),
      ),
    ].take(maxEntries).toList(growable: false);
    state = {...state, tab: next};
    await _repository.write(tab, next);
  }

  Future<void> remove(HomeDiscoveryTab tab, String query) async {
    final next = (state[tab] ?? const [])
        .where((item) => item != query)
        .toList(growable: false);
    state = {...state, tab: next};
    await _repository.write(tab, next);
  }

  Future<void> clear(HomeDiscoveryTab tab) async {
    state = {...state, tab: const []};
    await _repository.write(tab, const []);
  }
}

String normalizeSearchQuery(String query) =>
    query.trim().replaceAll(RegExp(r'\s+'), ' ');

final homeSearchHistoryProvider =
    NotifierProvider<
      HomeSearchHistoryController,
      Map<HomeDiscoveryTab, List<String>>
    >(HomeSearchHistoryController.new);
