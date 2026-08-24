import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

void main() {
  test(
    'history normalizes, de-duplicates, and keeps ten entries per tab',
    () async {
      final repository = _MemoryHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          homeSearchHistoryRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(homeSearchHistoryProvider.notifier);

      await controller.add(HomeDiscoveryTab.sessions, '  Sân   Quận 1  ');
      await controller.add(HomeDiscoveryTab.sessions, 'sân quận 1');
      for (var index = 0; index < 11; index++) {
        await controller.add(HomeDiscoveryTab.sessions, 'query $index');
      }
      await controller.add(HomeDiscoveryTab.venues, 'Sân A');

      final state = container.read(homeSearchHistoryProvider);
      expect(state[HomeDiscoveryTab.sessions], hasLength(10));
      expect(state[HomeDiscoveryTab.sessions]!.first, 'query 10');
      expect(
        state[HomeDiscoveryTab.sessions]!.where(
          (query) => query.toLowerCase() == 'sân quận 1',
        ),
        hasLength(0),
      );
      expect(state[HomeDiscoveryTab.venues], ['Sân A']);
    },
  );

  test('history removes one item and clears only the selected tab', () async {
    final repository = _MemoryHistoryRepository({
      HomeDiscoveryTab.sessions: ['alpha', 'beta'],
      HomeDiscoveryTab.clubs: ['club'],
    });
    final container = ProviderContainer(
      overrides: [
        homeSearchHistoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(homeSearchHistoryProvider.notifier);

    await controller.remove(HomeDiscoveryTab.sessions, 'alpha');
    await controller.clear(HomeDiscoveryTab.sessions);

    final state = container.read(homeSearchHistoryProvider);
    expect(state[HomeDiscoveryTab.sessions], isEmpty);
    expect(state[HomeDiscoveryTab.clubs], ['club']);
  });
}

class _MemoryHistoryRepository implements HomeSearchHistoryRepository {
  _MemoryHistoryRepository([
    Map<HomeDiscoveryTab, List<String>> initial = const {},
  ]) : values = {
         for (final entry in initial.entries) entry.key: [...entry.value],
       };

  final Map<HomeDiscoveryTab, List<String>> values;

  @override
  List<String> read(HomeDiscoveryTab tab) => values[tab] ?? const [];

  @override
  Future<void> write(HomeDiscoveryTab tab, List<String> queries) async {
    values[tab] = [...queries];
  }
}
