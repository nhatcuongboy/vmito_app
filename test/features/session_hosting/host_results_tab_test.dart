import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/features/court/application/live_session_controller.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/form/match_update_draft.dart';
import 'package:vmito_app/features/session/domain/repositories/session_repository.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

class _Repository extends Mock implements SessionRepository {}

class _DraftFake extends Fake implements MatchUpdateDraft {}

Widget _app(Widget child) => MaterialApp(
  locale: const Locale('vi'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => registerFallbackValue(_DraftFake()));
  final match = Match(
    id: 'match-1',
    sessionId: 'session-1',
    courtId: 'court-1',
    status: MatchStatus.finished,
    players: [
      const MatchPlayer(
        id: 'mp-1',
        playerId: 'p-1',
        player: MatchPlayerRef(id: 'p-1', name: 'Sơn', playerNumber: 1),
      ),
      const MatchPlayer(
        id: 'mp-2',
        playerId: 'p-2',
        position: 1,
        player: MatchPlayerRef(id: 'p-2', name: 'Minh', playerNumber: 2),
      ),
      const MatchPlayer(
        id: 'mp-3',
        playerId: 'p-3',
        position: 2,
        player: MatchPlayerRef(id: 'p-3', name: 'Nam', playerNumber: 3),
      ),
      const MatchPlayer(
        id: 'mp-4',
        playerId: 'p-4',
        position: 3,
        player: MatchPlayerRef(id: 'p-4', name: 'Bảo', playerNumber: 4),
      ),
    ],
    score:
        '[{"playerId":"p-1","score":21},{"playerId":"p-2","score":21},{"playerId":"p-3","score":16},{"playerId":"p-4","score":16}]',
    winnerIds: '["p-1","p-2"]',
    startTime: DateTime.utc(2026, 8, 11, 3, 34),
    endTime: DateTime.utc(2026, 8, 11, 3, 35),
  );

  final unscoredMatch = Match(
    id: 'match-2',
    sessionId: 'session-1',
    courtId: 'court-2',
    status: MatchStatus.finished,
    startTime: DateTime.utc(2026, 8, 11, 3, 57),
    players: [
      const MatchPlayer(
        id: 'mp-5',
        playerId: 'p-5',
        player: MatchPlayerRef(id: 'p-5', name: 'Anie'),
      ),
      const MatchPlayer(
        id: 'mp-6',
        playerId: 'p-6',
        position: 1,
        player: MatchPlayerRef(id: 'p-6', name: 'Player Pro'),
      ),
      const MatchPlayer(
        id: 'mp-7',
        playerId: 'p-7',
        position: 2,
        player: MatchPlayerRef(id: 'p-7', name: 'Sa Sa'),
      ),
      const MatchPlayer(
        id: 'mp-8',
        playerId: 'p-8',
        position: 3,
        player: MatchPlayerRef(id: 'p-8', name: 'Minh Lê'),
      ),
    ],
  );

  const session = Session(
    id: 'session-1',
    name: 'Kèo kết quả',
    status: SessionStatus.inProgress,
    courts: [
      Court(id: 'court-1', courtNumber: 1),
      Court(id: 'court-2', courtNumber: 2),
    ],
    players: [
      SessionPlayer(id: 'p-1', name: 'Sơn', playerNumber: 1),
      SessionPlayer(id: 'p-2', name: 'Minh', playerNumber: 2),
      SessionPlayer(id: 'p-3', name: 'Nam', playerNumber: 3),
      SessionPlayer(id: 'p-4', name: 'Bảo', playerNumber: 4),
      SessionPlayer(id: 'p-5', name: 'Anie', playerNumber: 5),
      SessionPlayer(id: 'p-6', name: 'Player Pro', playerNumber: 6),
      SessionPlayer(id: 'p-7', name: 'Sa Sa', playerNumber: 7),
      SessionPlayer(id: 'p-8', name: 'Minh Lê', playerNumber: 8),
    ],
  );

  test('parses one score per team and identifies the winning pair', () {
    final result = matchResult(match);
    expect(result.first, 21);
    expect(result.second, 16);
    expect(result.winner, 1);
  });

  test('uses alternating court positions for a vertical court', () {
    final verticalMatch = match.copyWith(
      score:
          '[{"playerId":"p-1","score":21},{"playerId":"p-2","score":16},{"playerId":"p-3","score":21},{"playerId":"p-4","score":16}]',
      winnerIds: '["p-1","p-3"]',
    );

    final result = matchResult(
      verticalMatch,
      direction: CourtDirection.vertical,
    );

    expect(result.first, 21);
    expect(result.second, 16);
    expect(result.winner, 1);
  });

  test('parses the compact pair score written by the web editor', () {
    final edited = match.copyWith(
      score: '{"pair1":19,"pair2":21}',
      winnerIds: '["p-3","p-4"]',
    );

    final result = matchResult(edited);

    expect(result.first, 19);
    expect(result.second, 21);
    expect(result.winner, 2);
  });

  testWidgets('renders compact controls and completed result card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kết quả (1)'), findsNothing);
    expect(find.byKey(const Key('host-results-filter')), findsOneWidget);
    expect(find.text('Mới nhất'), findsOneWidget);
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.text('Cặp 1'), findsOneWidget);
    expect(find.text('Cặp 2'), findsOneWidget);
    expect(find.text('#1 Sơn · #2 Minh'), findsOneWidget);
    expect(find.text('#3 Nam · #4 Bảo'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
    expect(find.text('Thắng'), findsOneWidget);
    expect(find.text('VS'), findsOneWidget);
    expect(find.textContaining('1 phút'), findsOneWidget);
  });

  testWidgets('renders the correct player pairs for a vertical court', (
    tester,
  ) async {
    final verticalMatch = match.copyWith(
      score:
          '[{"playerId":"p-1","score":21},{"playerId":"p-2","score":16},{"playerId":"p-3","score":21},{"playerId":"p-4","score":16}]',
      winnerIds: '["p-1","p-3"]',
    );
    final verticalSession = session.copyWith(
      courts: const [
        Court(
          id: 'court-1',
          courtNumber: 1,
          direction: CourtDirection.vertical,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionRealtimeProvider(
            verticalSession.id,
          ).overrideWith((ref) {}),
          matchHistoryProvider(
            verticalSession.id,
          ).overrideWith((ref) async => [verticalMatch]),
        ],
        child: _app(HostResultsTab(session: verticalSession)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('#1 Sơn · #3 Nam'), findsOneWidget);
    expect(find.text('#2 Minh · #4 Bảo'), findsOneWidget);
  });

  testWidgets('filters results from the sheet and clears filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith(
            (ref) async => [match, unscoredMatch],
          ),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-results-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('host-results-filter-court-court-2')),
    );
    await tester.tap(
      find.byKey(const Key('host-results-filter-result-withoutScore')),
    );
    await tester.tap(find.byKey(const Key('host-results-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-result-card-match-1')), findsNothing);
    expect(find.byKey(const Key('host-result-card-match-2')), findsOneWidget);
    expect(find.text('Đã lọc'), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-results-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-results-filter-reset')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-result-card-match-1')), findsOneWidget);
    expect(find.byKey(const Key('host-result-card-match-2')), findsOneWidget);
  });

  testWidgets('filters by any of the selected players', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith(
            (ref) async => [match, unscoredMatch],
          ),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-results-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('host-results-filter-player-p-1')),
    );
    await tester.tap(find.byKey(const Key('host-results-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-result-card-match-1')), findsOneWidget);
    expect(find.byKey(const Key('host-result-card-match-2')), findsNothing);

    await tester.tap(find.byKey(const Key('host-results-filter')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('host-results-filter-player-p-5')),
    );
    await tester.tap(find.byKey(const Key('host-results-filter-apply')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('host-result-card-match-1')), findsOneWidget);
    expect(find.byKey(const Key('host-result-card-match-2')), findsOneWidget);
  });

  testWidgets('edits a completed match from its bottom sheet', (tester) async {
    final repository = _Repository();
    when(
      () => repository.updateMatch('match-1', any()),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-result-edit-match-1')));
    await tester.pumpAndSettle();
    expect(find.text('Chỉnh sửa trận đấu'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('host-match-edit-score-1')),
      '22',
    );
    await tester.tap(find.byKey(const Key('host-match-edit-submit')));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repository.updateMatch('match-1', captureAny()),
            ).captured.single
            as MatchUpdateDraft;
    expect(captured.pair1Score, 22);
    expect(captured.pair1PlayerIds, ['p-1', 'p-2']);
    expect(find.text('Cập nhật trận đấu thành công'), findsOneWidget);
  });

  testWidgets('keeps the edit sheet open when updating fails', (tester) async {
    final repository = _Repository();
    when(
      () => repository.updateMatch('match-1', any()),
    ).thenThrow(StateError('failed'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-result-edit-match-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-match-edit-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Chỉnh sửa trận đấu'), findsOneWidget);
    expect(find.text('Không thể cập nhật trận đấu'), findsOneWidget);
  });

  testWidgets('submits an unscored match as no result', (tester) async {
    final repository = _Repository();
    when(
      () => repository.updateMatch('match-2', any()),
    ).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(
            session.id,
          ).overrideWith((ref) async => [unscoredMatch]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-result-edit-match-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-match-edit-submit')));
    await tester.pumpAndSettle();

    final captured =
        verify(
              () => repository.updateMatch('match-2', captureAny()),
            ).captured.single
            as MatchUpdateDraft;
    expect(captured.noResult, isTrue);
    expect(captured.toRequestBody()['score'], isNull);
  });

  testWidgets('confirms before deleting a completed match', (tester) async {
    final repository = _Repository();
    when(() => repository.deleteMatch('match-1')).thenAnswer((_) async {});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-result-delete-match-1')));
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận xóa'), findsOneWidget);
    verifyNever(() => repository.deleteMatch(any()));

    await tester.tap(find.byKey(const Key('host-result-delete-confirm')));
    await tester.pumpAndSettle();

    verify(() => repository.deleteMatch('match-1')).called(1);
    expect(find.text('Đã xóa trận đấu'), findsOneWidget);
  });

  testWidgets('keeps the confirmation open when deleting fails', (
    tester,
  ) async {
    final repository = _Repository();
    when(
      () => repository.deleteMatch('match-1'),
    ).thenThrow(StateError('failed'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionRepositoryProvider.overrideWithValue(repository),
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('host-result-delete-match-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('host-result-delete-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Xác nhận xóa'), findsOneWidget);
    expect(find.text('Không thể xóa trận đấu'), findsOneWidget);
  });

  testWidgets('sort menu switches to oldest first on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveSessionRealtimeProvider(session.id).overrideWith((ref) {}),
          matchHistoryProvider(session.id).overrideWith(
            (ref) async => [match, unscoredMatch],
          ),
        ],
        child: _app(const HostResultsTab(session: session)),
      ),
    );
    await tester.pumpAndSettle();

    final latestPosition = tester.getTopLeft(
      find.byKey(const Key('host-result-card-match-2')),
    );
    final oldestPosition = tester.getTopLeft(
      find.byKey(const Key('host-result-card-match-1')),
    );
    expect(latestPosition.dy, lessThan(oldestPosition.dy));

    await tester.tap(find.byKey(const Key('host-results-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cũ nhất'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('host-result-card-match-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('host-result-card-match-2'))).dy,
      ),
    );
    expect(find.text('Cũ nhất'), findsOneWidget);
  });
}
