import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_slot_placeholder.dart';
import 'package:vmito_app/features/session/application/player/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/court/court_selection_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

const _court = Court(id: 'c1', courtNumber: 2);

const _session = Session(
  id: 's1',
  name: 'Kèo test',
  status: SessionStatus.inProgress,
  courts: [_court],
  players: [
    SessionPlayer(id: 'a', name: 'An', playerNumber: 1, currentWaitTime: 30),
    SessionPlayer(id: 'b', name: 'Bình', playerNumber: 2, currentWaitTime: 20),
    SessionPlayer(id: 'c', name: 'Cường', playerNumber: 3, currentWaitTime: 12),
    SessionPlayer(id: 'd', name: 'Dũng', playerNumber: 44),
    SessionPlayer(id: 'e', name: 'Em', playerNumber: 5),
  ],
);

/// Gives the sheet a tall window.
///
/// The default 800x600 test surface puts the player grid below the fold, and
/// a `ListView` does not build what it cannot show — so the cards would not
/// exist to tap.
void useTallWindow(WidgetTester tester) {
  tester.view
    ..physicalSize = const Size(1200, 3000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpSheet(WidgetTester tester) async {
  useTallWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sessionDetailProvider('s1').overrideWith((ref) => _session),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('vi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: CourtSelectionSheet(
            selectionKey: (
              sessionId: 's1',
              courtId: 'c1',
              preSelect: false,
            ),
            court: _court,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

FilledButton confirmButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.byKey(const ValueKey('confirm-player-selection')),
);

void main() {
  testWidgets('confirm stays disabled until four seats are filled', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(confirmButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('player-card-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('player-card-b')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('player-card-c')));
    await tester.pump();
    // Three of four: still not a doubles match.
    expect(confirmButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('player-card-d')));
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('singles needs two, and switching formats clears the picks', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('player-card-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('player-card-b')));
    await tester.pump();

    await tester.tap(find.text('Đánh đơn'));
    await tester.pumpAndSettle();

    // The two earlier picks are gone: two empty seats, nothing confirmable.
    expect(find.byType(CourtSlotPlaceholder), findsNWidgets(2));
    expect(confirmButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('player-card-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('player-card-b')));
    await tester.pump();
    expect(confirmButton(tester).onPressed, isNotNull);
  });

  testWidgets('search matches a name and a shirt number', (tester) async {
    await pumpSheet(tester);

    await tester.enterText(find.byType(TextField), 'Dũng');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-card-d')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-card-a')), findsNothing);

    // A host calling "số 44" should not have to remember the name.
    await tester.enterText(find.byType(TextField), '44');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-card-d')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-card-a')), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy người chơi'), findsOneWidget);
  });

  testWidgets('only WAITING players are offered', (tester) async {
    useTallWindow(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider('s1').overrideWith(
            (ref) => const Session(
              id: 's1',
              name: 'Kèo test',
              status: SessionStatus.inProgress,
              courts: [_court],
              players: [
                SessionPlayer(id: 'onCourt', status: PlayerStatus.playing),
              ],
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: CourtSelectionSheet(
              selectionKey: (
                sessionId: 's1',
                courtId: 'c1',
                preSelect: false,
              ),
              court: _court,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Hiện tại không có người chơi nào đang chờ'),
      findsWidgets,
    );
  });
}
