import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/home/application/home_search_history.dart';
import 'package:vmito_app/features/home/application/home_search_suggestions.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/home/domain/home_search_outcome.dart';
import 'package:vmito_app/features/home/presentation/home_search_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

const _featuredSession = DiscoverySuggestion(
  tab: HomeDiscoveryTab.sessions,
  entityId: 'featured-1',
  title: 'Sân Đại Phát',
  subtitle: 'Đại Phát',
);

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
    expect(find.text('Tìm kiếm gần đây'), findsNothing);
    expect(repository.values[HomeDiscoveryTab.sessions], isEmpty);
  });

  testWidgets('collapses long history and expands it in place', (
    tester,
  ) async {
    final queries = ['một', 'hai', 'ba', 'bốn', 'năm'];
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository({
          HomeDiscoveryTab.sessions: queries,
        }),
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    expect(find.text('ba'), findsOneWidget);
    expect(find.text('bốn'), findsNothing);
    expect(find.text('Xem tất cả (5)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-search-history-toggle')));
    await tester.pump();

    expect(find.text('năm'), findsOneWidget);
    expect(find.text('Thu gọn'), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-search-history-toggle')));
    await tester.pump();

    expect(find.text('bốn'), findsNothing);
  });

  testWidgets('clear query empties an initial search value', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        initialQuery: 'đi',
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(
          featuredItems: const [_featuredSession],
        ),
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
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byKey(const Key('home-search-clear-query')), findsNothing);
    expect(find.text('Kèo còn chỗ sắp diễn ra'), findsOneWidget);
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
  });

  testWidgets('shows the featured preview and pops its preset on see all', (
    tester,
  ) async {
    final outcomes = <HomeSearchOutcome?>[];
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(
          featuredItems: const [_featuredSession],
        ),
        onPopped: outcomes.add,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kèo còn chỗ sắp diễn ra'), findsOneWidget);
    expect(find.text('Sân Đại Phát', findRichText: true), findsOneWidget);
    // The place is already in the name, so the detail line drops it.
    expect(find.text('Đại Phát'), findsNothing);

    await tester.tap(find.byKey(const Key('home-search-featured-see-all')));
    await tester.pumpAndSettle();

    expect(outcomes.single, isA<HomeSearchPreset>());
    expect(
      (outcomes.single! as HomeSearchPreset).tab,
      HomeDiscoveryTab.sessions,
    );
  });

  testWidgets('hides an empty featured preview', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Kèo còn chỗ sắp diễn ra'), findsNothing);
  });

  testWidgets('retries a failed featured preview', (tester) async {
    final service = _FakeSuggestionService(featuredError: StateError('down'));
    await tester.pumpWidget(
      _TestApp(
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: service,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Không tải được gợi ý.'), findsOneWidget);

    service
      ..featuredError = null
      ..featuredItems = const [_featuredSession];
    await tester.tap(find.byKey(const Key('home-search-featured-retry')));
    await tester.pump();
    await tester.pump();

    expect(service.featuredCalls, 2);
    expect(find.text('Sân Đại Phát', findRichText: true), findsOneWidget);
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
    expect(find.text('Kèo Quang Hưng', findRichText: true), findsOneWidget);
    expect(find.text('Sân A'), findsOneWidget);
    expect(
      find.text('Xem tất cả kết quả cho ‘quang hung’', findRichText: true),
      findsOneWidget,
    );
    // The accent-free keyword still highlights the accented name.
    final title = tester.widget<RichText>(
      find.text('Kèo Quang Hưng', findRichText: true),
    );
    final spans = (title.text as TextSpan).children!.first as TextSpan;
    expect(
      spans.children!.map((span) => (span as TextSpan).text),
      ['Kèo ', 'Quang Hưng', ''],
    );
  });

  testWidgets('submitting pops the query and records it', (tester) async {
    final outcomes = <HomeSearchOutcome?>[];
    final repository = _MemoryHistoryRepository();
    await tester.pumpWidget(
      _TestApp(
        historyRepository: repository,
        suggestionService: _FakeSuggestionService(),
        onPopped: outcomes.add,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '  cầu   lông ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect((outcomes.single! as HomeSearchQuery).query, 'cầu lông');
    expect(repository.values[HomeDiscoveryTab.sessions], ['cầu lông']);
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

    expect(find.text('Kết quả mới', findRichText: true), findsOneWidget);
    expect(find.text('Kết quả cũ', findRichText: true), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.historyRepository,
    required this.suggestionService,
    this.initialQuery = '',
    this.onPopped,
  });

  final HomeSearchHistoryRepository historyRepository;
  final HomeSearchSuggestionService suggestionService;
  final String initialQuery;

  /// When set, the screen is pushed as a route so its pop result is seen.
  final ValueChanged<HomeSearchOutcome?>? onPopped;

  @override
  Widget build(BuildContext context) {
    final screen = HomeSearchScreen(
      tab: HomeDiscoveryTab.sessions,
      initialQuery: initialQuery,
    );
    final onPopped = this.onPopped;
    return ProviderScope(
      overrides: [
        homeSearchHistoryRepositoryProvider.overrideWithValue(
          historyRepository,
        ),
        homeSearchSuggestionServiceProvider.overrideWithValue(
          suggestionService,
        ),
        locationPreferencesControllerProvider.overrideWith(
          _FixedLocationPreferences.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: onPopped == null
            ? screen
            : _Launcher(screen: screen, onPopped: onPopped),
      ),
    );
  }
}

class _Launcher extends StatefulWidget {
  const _Launcher({required this.screen, required this.onPopped});

  final Widget screen;
  final ValueChanged<HomeSearchOutcome?> onPopped;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final result = await Navigator.of(context).push<HomeSearchOutcome>(
        MaterialPageRoute(builder: (_) => widget.screen),
      );
      widget.onPopped(result);
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

class _FixedLocationPreferences extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    selectionType: LocationSelectionType.city,
    onboardingCompleted: true,
    isRestored: true,
  );
}

class _FakeSuggestionService implements HomeSearchSuggestionService {
  _FakeSuggestionService({
    this.suggestions = const [],
    this.featuredItems = const [],
    this.featuredError,
  });

  final List<DiscoverySuggestion> suggestions;
  List<DiscoverySuggestion> featuredItems;
  Error? featuredError;
  final queries = <String>[];
  int featuredCalls = 0;

  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
  }) async {
    queries.add(query);
    return suggestions;
  }

  @override
  Future<List<DiscoverySuggestion>> featured(HomeDiscoveryTab tab) async {
    featuredCalls++;
    if (featuredError case final error?) throw error;
    return featuredItems;
  }
}

class _ControlledSuggestionService implements HomeSearchSuggestionService {
  final requests = <String, Completer<List<DiscoverySuggestion>>>{};

  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
  }) {
    final completer = Completer<List<DiscoverySuggestion>>();
    requests[query] = completer;
    return completer.future;
  }

  @override
  Future<List<DiscoverySuggestion>> featured(HomeDiscoveryTab tab) async =>
      const [];
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
