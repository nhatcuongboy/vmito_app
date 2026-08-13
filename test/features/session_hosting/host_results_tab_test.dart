import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/court/application/match_history_provider.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_results_tab.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  final match = Match(
    id: 'match-1',
    sessionId: 'session-1',
    courtId: 'court-1',
    status: MatchStatus.finished,
    players: [
      const MatchPlayer(
        id: 'mp-1',
        playerId: 'p-1',
        player: MatchPlayerRef(id: 'p-1', name: 'Sơn'),
      ),
      const MatchPlayer(
        id: 'mp-2',
        playerId: 'p-2',
        position: 1,
        player: MatchPlayerRef(id: 'p-2', name: 'Minh'),
      ),
      const MatchPlayer(
        id: 'mp-3',
        playerId: 'p-3',
        position: 2,
        player: MatchPlayerRef(id: 'p-3', name: 'Nam'),
      ),
      const MatchPlayer(
        id: 'mp-4',
        playerId: 'p-4',
        position: 3,
        player: MatchPlayerRef(id: 'p-4', name: 'Bảo'),
      ),
    ],
    score:
        '[{"playerId":"p-1","score":21},{"playerId":"p-2","score":21},{"playerId":"p-3","score":16},{"playerId":"p-4","score":16}]',
    winnerIds: '["p-1","p-2"]',
    startTime: DateTime.utc(2026, 8, 11, 3, 34),
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
      SessionPlayer(id: 'p-1', name: 'Sơn'),
      SessionPlayer(id: 'p-2', name: 'Minh'),
      SessionPlayer(id: 'p-3', name: 'Nam'),
      SessionPlayer(id: 'p-4', name: 'Bảo'),
      SessionPlayer(id: 'p-5', name: 'Anie'),
      SessionPlayer(id: 'p-6', name: 'Player Pro'),
      SessionPlayer(id: 'p-7', name: 'Sa Sa'),
      SessionPlayer(id: 'p-8', name: 'Minh Lê'),
    ],
  );

  test('parses one score per team and identifies the winning pair', () {
    final result = matchResult(match);
    expect(result.first, 21);
    expect(result.second, 16);
    expect(result.winner, 1);
  });

  testWidgets('renders compact controls and completed result card', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchHistoryProvider(session.id).overrideWith((ref) async => [match]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HostResultsTab(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kết quả (1)'), findsNothing);
    expect(find.byKey(const Key('host-results-filter')), findsOneWidget);
    expect(find.text('Mới nhất'), findsOneWidget);
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.text('Sơn • Minh'), findsOneWidget);
    expect(find.text('Nam • Bảo'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });

  testWidgets('filters results from the sheet and clears filters', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchHistoryProvider(session.id).overrideWith(
            (ref) async => [match, unscoredMatch],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HostResultsTab(session: session)),
        ),
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

  testWidgets('sort menu switches to oldest first on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchHistoryProvider(session.id).overrideWith(
            (ref) async => [match, unscoredMatch],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: HostResultsTab(session: session)),
        ),
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
