import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/match_result_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

const _players = [
  SessionPlayer(id: 'a', name: 'An', position: 0),
  SessionPlayer(id: 'b', name: 'Bình', position: 1),
  SessionPlayer(id: 'c', name: 'Cường', position: 2),
  SessionPlayer(id: 'd', name: 'Dũng', position: 3),
];

const _court = Court(
  id: 'c1',
  courtNumber: 1,
  status: CourtStatus.inUse,
  currentMatchId: 'm1',
  currentPlayers: _players,
);

const _session = Session(
  id: 's1',
  name: 'Kèo test',
  status: SessionStatus.inProgress,
  courts: [_court],
  players: _players,
);

Future<MatchResultDraft?> pumpAndSubmit(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) interact, {
  ValueKey<String> submit = const ValueKey('submit-match-result'),
}) async {
  tester.view
    ..physicalSize = const Size(1200, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  MatchResultDraft? captured;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              captured = await showMatchResultSheet(
                context,
                session: _session,
                court: _court,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await interact(tester);
  await tester.tap(find.byKey(submit));
  await tester.pumpAndSettle();
  return captured;
}

void main() {
  testWidgets('scores decide the winner without an extra tap', (tester) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      await tester.enterText(_scoreField(1), '21');
      await tester.enterText(_scoreField(2), '18');
      await tester.pump();
    });

    expect(draft, isNotNull);
    // Every player on the winning side, not just the first.
    expect(draft!.winnerIds, ['a', 'b']);
    expect(draft.score.map((s) => '${s.playerId}:${s.score}'), [
      'a:21',
      'b:21',
      'c:18',
      'd:18',
    ]);
  });

  testWidgets('a draw clears the winner', (tester) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      await tester.enterText(_scoreField(1), '21');
      await tester.enterText(_scoreField(2), '18');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('match-result-draw')));
      await tester.pump();
    });

    expect(draft!.isDraw, isTrue);
    expect(draft.winnerIds, isEmpty);
    // The scores stay: a draw still has a scoreline.
    expect(draft.score, hasLength(4));
  });

  testWidgets('tapping a team names it the winner with no score at all', (
    tester,
  ) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      // Tap the label, not the card's centre — that is the score box.
      await tester.tap(_teamLabel(2));
      await tester.pump();
    });

    expect(draft!.winnerIds, ['c', 'd']);
    expect(draft.score, isEmpty);
    expect(draft.toRequestBody().containsKey('score'), isFalse);
  });

  testWidgets('tapping the same team again clears the winner', (tester) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      await tester.tap(_teamLabel(1));
      await tester.pump();
      await tester.tap(_teamLabel(1));
      await tester.pump();
    });

    expect(draft!.winnerIds, isEmpty);
  });

  // Most sessions never score their matches; ending must not require it.
  testWidgets('skipping submits an empty draft, not null', (tester) async {
    final draft = await pumpAndSubmit(
      tester,
      (tester) async {},
      submit: const ValueKey('skip-match-result'),
    );

    expect(draft, isNotNull);
    expect(draft!.toRequestBody(), isEmpty);
  });

  testWidgets('notes and shuttlecocks reach the request body', (tester) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('match-result-shuttlecocks')),
        '2.5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('match-result-notes')),
        '  Sân trơn  ',
      );
      await tester.pump();
    });

    final body = draft!.toRequestBody();
    expect(body['shuttlecockCount'], 2.5);
    expect(body['notes'], 'Sân trơn');
  });

  testWidgets('whitespace-only notes are omitted rather than sent empty', (
    tester,
  ) async {
    final draft = await pumpAndSubmit(tester, (tester) async {
      await tester.enterText(
        find.byKey(const ValueKey('match-result-notes')),
        '   ',
      );
      await tester.pump();
    });

    expect(draft!.toRequestBody().containsKey('notes'), isFalse);
  });
}

/// The tappable label of pair [pair] (1-based).
Finder _teamLabel(int pair) => find.descendant(
  of: find.byKey(ValueKey('match-result-pair-$pair')),
  matching: find.text(pair == 1 ? 'Cặp 1' : 'Cặp 2'),
);

/// The score box inside pair [pair] (1-based).
Finder _scoreField(int pair) => find.descendant(
  of: find.byKey(ValueKey('match-result-pair-$pair')),
  matching: find.byType(TextField),
);
