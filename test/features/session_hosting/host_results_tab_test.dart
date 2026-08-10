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
  const match = Match(
    id: 'match-1',
    sessionId: 'session-1',
    courtId: 'court-1',
    status: MatchStatus.finished,
    players: [
      MatchPlayer(
        id: 'mp-1',
        playerId: 'p-1',
        player: MatchPlayerRef(id: 'p-1', name: 'Sơn'),
      ),
      MatchPlayer(
        id: 'mp-2',
        playerId: 'p-2',
        position: 1,
        player: MatchPlayerRef(id: 'p-2', name: 'Minh'),
      ),
      MatchPlayer(
        id: 'mp-3',
        playerId: 'p-3',
        position: 2,
        player: MatchPlayerRef(id: 'p-3', name: 'Nam'),
      ),
      MatchPlayer(
        id: 'mp-4',
        playerId: 'p-4',
        position: 3,
        player: MatchPlayerRef(id: 'p-4', name: 'Bảo'),
      ),
    ],
    score:
        '[{"playerId":"p-1","score":21},{"playerId":"p-2","score":21},{"playerId":"p-3","score":16},{"playerId":"p-4","score":16}]',
    winnerIds: '["p-1","p-2"]',
  );

  const session = Session(
    id: 'session-1',
    name: 'Kèo kết quả',
    status: SessionStatus.inProgress,
    courts: [Court(id: 'court-1', courtNumber: 1)],
    players: [
      SessionPlayer(id: 'p-1', name: 'Sơn'),
      SessionPlayer(id: 'p-2', name: 'Minh'),
      SessionPlayer(id: 'p-3', name: 'Nam'),
      SessionPlayer(id: 'p-4', name: 'Bảo'),
    ],
  );

  test('parses one score per team and identifies the winning pair', () {
    final result = matchResult(match);
    expect(result.first, 21);
    expect(result.second, 16);
    expect(result.winner, 1);
  });

  testWidgets('renders completed result card from match history', (
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

    expect(find.text('Kết quả (1)'), findsOneWidget);
    expect(find.text('Sân 1'), findsOneWidget);
    expect(find.text('Sơn • Minh'), findsOneWidget);
    expect(find.text('Nam • Bảo'), findsOneWidget);
    expect(find.text('21'), findsOneWidget);
    expect(find.text('16'), findsOneWidget);
  });
}
