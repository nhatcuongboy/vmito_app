import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/home/application/home_search_suggestions.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/home/presentation/home_search_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows tab history and removes an entry', (tester) async {
    final repository = _MemoryHistoryRepository({
      HomeDiscoveryTab.sessions: ['Kèo tối nay'],
    });
    await tester.pumpWidget(
      _TestApp(
        historyRepository: repository,
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    expect(find.text('Tìm kiếm gần đây'), findsOneWidget);
    expect(find.text('Kèo tối nay'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa khỏi lịch sử'));
    await tester.pump();

    expect(find.text('Kèo tối nay'), findsNothing);
    expect(repository.values[HomeDiscoveryTab.sessions], isEmpty);
  });

  testWidgets('clear query empties an initial search value', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        initialQuery: 'đi',
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('home-search-clear-query')), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'đi',
    );

    await tester.tap(find.byKey(const Key('home-search-clear-query')));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byKey(const Key('home-search-clear-query')), findsNothing);
    expect(find.text('Chưa có tìm kiếm gần đây.'), findsOneWidget);
  });

  testWidgets('submitting a cleared query keeps focus and shows inline error', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        initialQuery: 'đi',
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('home-search-clear-query')));
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.focusNode?.hasFocus, isTrue);
    expect(find.text('Vui lòng nhập từ khóa tìm kiếm'), findsOneWidget);
    expect(find.text('Chưa có tìm kiếm gần đây.'), findsOneWidget);
  });

  testWidgets('debounces input and renders entity suggestions', (tester) async {
    final service = _FakeSuggestionService(
      suggestions: const [
        DiscoverySuggestion(
          tab: HomeDiscoveryTab.sessions,
          entityId: 'session-1',
          title: 'Kèo Quang Hưng',
          subtitle: 'Sân A',
        ),
      ],
    );
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: service,
      ),
    );

    await tester.enterText(find.byType(TextField), 'quang hung');
    await tester.pump(const Duration(milliseconds: 399));
    expect(service.queries, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(service.queries, ['quang hung']);
    expect(find.text('Kèo Quang Hưng'), findsOneWidget);
    expect(find.text('Tìm kiếm ‘quang hung’'), findsOneWidget);
  });

  testWidgets('ignores a stale suggestion response', (tester) async {
    final service = _ControlledSuggestionService();
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: service,
      ),
    );

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(const Duration(milliseconds: 400));

    service.requests['beta']!.complete(const [
      DiscoverySuggestion(
        tab: HomeDiscoveryTab.sessions,
        entityId: 'new',
        title: 'Kết quả mới',
      ),
    ]);
    await tester.pump();
    service.requests['alpha']!.complete(const [
      DiscoverySuggestion(
        tab: HomeDiscoveryTab.sessions,
        entityId: 'old',
        title: 'Kết quả cũ',
      ),
    ]);
    await tester.pump();

    expect(find.text('Kết quả mới'), findsOneWidget);
    expect(find.text('Kết quả cũ'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.historyRepository,
    required this.suggestionService,
    this.initialQuery = '',
  });

  final HomeSearchHistoryRepository historyRepository;
  final HomeSearchSuggestionService suggestionService;
  final String initialQuery;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      homeSearchHistoryRepositoryProvider.overrideWithValue(historyRepository),
      homeSearchSuggestionServiceProvider.overrideWithValue(suggestionService),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeSearchScreen(
        tab: HomeDiscoveryTab.sessions,
        initialQuery: initialQuery,
      ),
    ),
  );
}

class _FakeSuggestionService implements HomeSearchSuggestionService {
  _FakeSuggestionService({this.suggestions = const []});

  final List<DiscoverySuggestion> suggestions;
  final queries = <String>[];

  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
    String? city,
  }) async {
    queries.add(query);
    return suggestions;
  }
}

class _ControlledSuggestionService implements HomeSearchSuggestionService {
  final requests = <String, Completer<List<DiscoverySuggestion>>>{};

  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
    String? city,
  }) {
    final completer = Completer<List<DiscoverySuggestion>>();
    requests[query] = completer;
    return completer.future;
  }
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
