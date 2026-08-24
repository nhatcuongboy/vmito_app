import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_history.dart';
import 'package:vmito_app/features/session/application/player/my_sessions_search_suggestions.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/presentation/player/my_sessions_search_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('shows history only for the active scope', (tester) async {
    final repository = _MemoryHistoryRepository({
      MySessionScope.hosted: ['Kèo quản lý'],
      MySessionScope.joined: ['Kèo tham gia cũ'],
    });
    await tester.pumpWidget(
      _TestApp(
        scope: MySessionScope.hosted,
        historyRepository: repository,
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    expect(find.text('Kèo quản lý'), findsOneWidget);
    expect(find.text('Kèo tham gia cũ'), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );

    await tester.tap(find.byTooltip('Xóa khỏi lịch sử'));
    await tester.pump();
    expect(repository.values[MySessionScope.hosted], isEmpty);
    expect(repository.values[MySessionScope.joined], ['Kèo tham gia cũ']);
  });

  testWidgets('validates an empty submitted query', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        scope: MySessionScope.hosted,
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: _FakeSuggestionService(),
      ),
    );
    await tester.pump();

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Vui lòng nhập từ khóa tìm kiếm'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus,
      isTrue,
    );
  });

  testWidgets('debounces suggestions and passes the active scope', (
    tester,
  ) async {
    final service = _FakeSuggestionService(
      suggestions: [_session('s1', 'Kèo tối')],
    );
    await tester.pumpWidget(
      _TestApp(
        scope: MySessionScope.joined,
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: service,
      ),
    );

    await tester.enterText(find.byType(TextField), 'kèo tối');
    await tester.pump(const Duration(milliseconds: 399));
    expect(service.requests, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(service.requests, [(MySessionScope.joined, 'kèo tối')]);
    expect(find.text('Kèo tối'), findsOneWidget);
    expect(find.text('Tìm kiếm ‘kèo tối’'), findsOneWidget);
  });

  testWidgets('ignores a stale suggestion response', (tester) async {
    final service = _ControlledSuggestionService();
    await tester.pumpWidget(
      _TestApp(
        scope: MySessionScope.hosted,
        historyRepository: _MemoryHistoryRepository(),
        suggestionService: service,
      ),
    );

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(const Duration(milliseconds: 400));

    service.requests['beta']!.complete([_session('new', 'Kết quả mới')]);
    await tester.pump();
    service.requests['alpha']!.complete([_session('old', 'Kết quả cũ')]);
    await tester.pump();

    expect(find.text('Kết quả mới'), findsOneWidget);
    expect(find.text('Kết quả cũ'), findsNothing);
  });

  testWidgets('opens a selected session suggestion', (tester) async {
    final router = GoRouter(
      initialLocation: '/search',
      routes: [
        GoRoute(
          path: '/search',
          builder: (_, _) => const MySessionsSearchScreen(
            scope: MySessionScope.hosted,
          ),
        ),
        GoRoute(
          path: '/sessions/:id',
          builder: (_, state) => Text('detail-${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mySessionsSearchHistoryRepositoryProvider.overrideWithValue(
            _MemoryHistoryRepository(),
          ),
          mySessionsSearchSuggestionServiceProvider.overrideWithValue(
            _FakeSuggestionService(
              suggestions: [_session('s1', 'Kèo tối')],
            ),
          ),
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

    await tester.enterText(find.byType(TextField), 'kèo tối');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('my-sessions-search-suggestion-s1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('detail-s1'), findsOneWidget);
  });
}

Session _session(String id, String name) => Session(
  id: id,
  name: name,
  status: SessionStatus.preparing,
  location: 'Sân A',
);

class _TestApp extends StatelessWidget {
  const _TestApp({
    required this.scope,
    required this.historyRepository,
    required this.suggestionService,
  });

  final MySessionScope scope;
  final MySessionsSearchHistoryRepository historyRepository;
  final MySessionsSearchSuggestionService suggestionService;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [
      mySessionsSearchHistoryRepositoryProvider.overrideWithValue(
        historyRepository,
      ),
      mySessionsSearchSuggestionServiceProvider.overrideWithValue(
        suggestionService,
      ),
    ],
    child: MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MySessionsSearchScreen(scope: scope),
    ),
  );
}

class _FakeSuggestionService implements MySessionsSearchSuggestionService {
  _FakeSuggestionService({this.suggestions = const []});

  final List<Session> suggestions;
  final requests = <(MySessionScope, String)>[];

  @override
  Future<List<Session>> search({
    required MySessionScope scope,
    required String query,
  }) async {
    requests.add((scope, query));
    return suggestions;
  }
}

class _ControlledSuggestionService
    implements MySessionsSearchSuggestionService {
  final requests = <String, Completer<List<Session>>>{};

  @override
  Future<List<Session>> search({
    required MySessionScope scope,
    required String query,
  }) {
    final completer = Completer<List<Session>>();
    requests[query] = completer;
    return completer.future;
  }
}

class _MemoryHistoryRepository implements MySessionsSearchHistoryRepository {
  _MemoryHistoryRepository([
    Map<MySessionScope, List<String>> initial = const {},
  ]) : values = {
         for (final entry in initial.entries) entry.key: [...entry.value],
       };

  final Map<MySessionScope, List<String>> values;

  @override
  List<String> read(MySessionScope scope) => values[scope] ?? const [];

  @override
  Future<void> write(MySessionScope scope, List<String> queries) async {
    values[scope] = [...queries];
  }
}
