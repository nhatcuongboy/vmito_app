import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_player_marker.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_slot_placeholder.dart';
import 'package:vmito_app/features/court/presentation/widgets/court/court_view_mode.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/session_player.dart';

SessionPlayer player(String id, {String? name, int? seat, int? number}) =>
    SessionPlayer(id: id, name: name, position: seat, playerNumber: number);

Future<void> pumpCourt(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('vi'),
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 402, child: child)),
    ),
  );
  await tester.pump();
}

/// Where a marker's centre sits inside the court box, 0..1 on each axis.
Offset relativeCentre(WidgetTester tester, Finder finder) {
  final court = tester.getRect(find.byType(AspectRatio));
  final centre = tester.getCenter(finder);
  return Offset(
    (centre.dx - court.left) / court.width,
    (centre.dy - court.top) / court.height,
  );
}

void main() {
  group('display mode', () {
    for (final locale in const [Locale('vi'), Locale('en'), Locale('zh')]) {
      testWidgets('renders players in ${locale.languageCode}', (tester) async {
        const court = Court(
          id: 'court-1',
          courtNumber: 1,
          status: CourtStatus.inUse,
          currentPlayers: [
            SessionPlayer(id: 'p1', name: 'An', position: 0),
            SessionPlayer(id: 'p2', name: 'Bình', position: 1),
            SessionPlayer(id: 'p3', playerNumber: 3, position: 2),
            SessionPlayer(id: 'p4', name: 'Dũng', position: 3),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(
                width: 402,
                child: BadmintonCourtView(court: court),
              ),
            ),
          ),
        );

        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.text('An'), findsOneWidget);
        expect(find.text('Bình'), findsOneWidget);
        expect(find.text('Dũng'), findsOneWidget);
        expect(find.byType(AspectRatio), findsOneWidget);
      });
    }

    // The backend always sends positions, but a payload that lost them used to
    // stack every player in slot 0 and render one of four.
    testWidgets('players with no position all still render', (tester) async {
      const court = Court(
        id: 'court-1',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [
          SessionPlayer(id: 'p1', name: 'An'),
          SessionPlayer(id: 'p2', name: 'Bình'),
          SessionPlayer(id: 'p3', name: 'Cường'),
          SessionPlayer(id: 'p4', name: 'Dũng'),
        ],
      );

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(find.byType(CourtPlayerMarker), findsNWidgets(4));
    });

    testWidgets('duplicate seats fall back to arrival order', (tester) async {
      const court = Court(
        id: 'court-1',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [
          SessionPlayer(id: 'p1', name: 'An', position: 2),
          SessionPlayer(id: 'p2', name: 'Bình', position: 2),
        ],
      );

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(find.text('An'), findsOneWidget);
      expect(find.text('Bình'), findsOneWidget);
    });

    testWidgets('an empty court draws no seats outside selection', (
      tester,
    ) async {
      const court = Court(id: 'c', courtNumber: 1);

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(find.byType(CourtPlayerMarker), findsNothing);
      expect(find.byType(CourtSlotPlaceholder), findsNothing);
    });
  });

  group('direction is a coordinate transform', () {
    // Teams are always the left column against the right. Direction only moves
    // which API seat lands where — horizontal puts seats 0 and 1 on the left,
    // vertical puts 0 and 2 there.
    const players = [
      SessionPlayer(id: 'p0', name: 'Zero', position: 0),
      SessionPlayer(id: 'p1', name: 'One', position: 1),
      SessionPlayer(id: 'p2', name: 'Two', position: 2),
      SessionPlayer(id: 'p3', name: 'Three', position: 3),
    ];

    testWidgets('horizontal seats 0 and 1 share the left half', (tester) async {
      const court = Court(
        id: 'c',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: players,
      );

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(relativeCentre(tester, find.text('Zero')).dx, lessThan(0.5));
      expect(relativeCentre(tester, find.text('One')).dx, lessThan(0.5));
      expect(relativeCentre(tester, find.text('Two')).dx, greaterThan(0.5));
      expect(relativeCentre(tester, find.text('Three')).dx, greaterThan(0.5));
      // Seat 1 is drawn below seat 0, not beside it.
      expect(
        relativeCentre(tester, find.text('One')).dy,
        greaterThan(relativeCentre(tester, find.text('Zero')).dy),
      );
    });

    testWidgets('vertical seats 0 and 2 share the left half', (tester) async {
      const court = Court(
        id: 'c',
        courtNumber: 1,
        status: CourtStatus.inUse,
        direction: CourtDirection.vertical,
        currentPlayers: players,
      );

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(relativeCentre(tester, find.text('Zero')).dx, lessThan(0.5));
      expect(relativeCentre(tester, find.text('Two')).dx, lessThan(0.5));
      expect(relativeCentre(tester, find.text('One')).dx, greaterThan(0.5));
      expect(relativeCentre(tester, find.text('Three')).dx, greaterThan(0.5));
    });

    testWidgets('singles draws two seats, one per half', (tester) async {
      const court = Court(
        id: 'c',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [
          SessionPlayer(id: 'p0', name: 'Zero', position: 0),
          SessionPlayer(id: 'p1', name: 'One', position: 1),
        ],
      );

      await pumpCourt(tester, const BadmintonCourtView(court: court));

      expect(find.byType(CourtPlayerMarker), findsNWidgets(2));
      expect(relativeCentre(tester, find.text('Zero')).dx, lessThan(0.5));
      expect(relativeCentre(tester, find.text('One')).dx, greaterThan(0.5));
      // Both sit on the centre line rather than in a corner.
      expect(relativeCentre(tester, find.text('Zero')).dy, closeTo(0.5, 0.05));
    });
  });

  group('manage mode', () {
    testWidgets('shows the level badge a player view hides', (tester) async {
      const court = Court(
        id: 'c',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [
          SessionPlayer(id: 'p1', name: 'An', position: 0, level: 6),
        ],
      );

      await pumpCourt(
        tester,
        const BadmintonCourtView(court: court, mode: CourtViewMode.manage),
      );
      expect(find.text('Khá'), findsOneWidget);

      // A player watching a session has no business seeing everyone's rating.
      await pumpCourt(
        tester,
        // Spelled out even though it is the default: the contrast with the
        // call above is what this test asserts.
        // ignore: avoid_redundant_argument_values
        const BadmintonCourtView(court: court, mode: CourtViewMode.display),
      );
      expect(find.text('Khá'), findsNothing);
    });

    testWidgets('number display mode shows the shirt number', (tester) async {
      final court = Court(
        id: 'c',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [player('p1', name: 'An', seat: 0, number: 7)],
      );

      await pumpCourt(
        tester,
        BadmintonCourtView(
          court: court,
          displayMode: CourtDisplayMode.number,
        ),
      );

      expect(find.text('#7'), findsOneWidget);
      expect(find.text('An'), findsNothing);
    });
  });

  group('selection mode', () {
    testWidgets('draws a numbered placeholder for every empty seat', (
      tester,
    ) async {
      const court = Court(id: 'c', courtNumber: 1);

      await pumpCourt(
        tester,
        const BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: MatchType.doubles,
          selection: [null, null, null, null],
          activeSlot: 0,
        ),
      );

      expect(find.byType(CourtSlotPlaceholder), findsNWidgets(4));
      // Slot labels are 1-based for the host.
      for (final label in ['1', '2', '3', '4']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('singles draws two placeholders, not four', (tester) async {
      const court = Court(id: 'c', courtNumber: 1);

      await pumpCourt(
        tester,
        const BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: MatchType.singles,
          selection: [null, null],
          activeSlot: 0,
        ),
      );

      expect(find.byType(CourtSlotPlaceholder), findsNWidgets(2));
    });

    testWidgets('tapping reports the seat index, not the drawn position', (
      tester,
    ) async {
      const court = Court(id: 'c', courtNumber: 1);
      final tapped = <int>[];

      await pumpCourt(
        tester,
        BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: MatchType.doubles,
          selection: const [null, null, null, null],
          activeSlot: 0,
          onSlotTap: tapped.add,
        ),
      );

      // Seat 1 is drawn bottom-left on a horizontal court; the callback must
      // still say 1, or the host's pick lands in the wrong slot.
      await tester.tap(find.text('2'));
      expect(tapped, [1]);
    });

    testWidgets('a filled seat ignores taps so only the remove button clears it', (
      tester,
    ) async {
      const court = Court(id: 'c', courtNumber: 1);
      final tapped = <int>[];

      await pumpCourt(
        tester,
        BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: MatchType.doubles,
          selection: [
            player('p1', name: 'An', seat: 0),
            null,
            null,
            null,
          ],
          activeSlot: 1,
          onSlotTap: tapped.add,
        ),
      );

      await tester.tap(find.text('An'));
      expect(tapped, isEmpty);
    });

    testWidgets('shows a level badge and an explicit remove button', (
      tester,
    ) async {
      const court = Court(id: 'c', courtNumber: 1);
      final tapped = <int>[];

      await pumpCourt(
        tester,
        BadmintonCourtView(
          court: court,
          mode: CourtViewMode.selection,
          matchType: MatchType.doubles,
          selection: const [
            SessionPlayer(id: 'p1', name: 'An', position: 0, level: 6),
            null,
            null,
            null,
          ],
          activeSlot: 1,
          onSlotTap: tapped.add,
        ),
      );

      expect(find.text('Khá'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('remove-selected-court-player')),
      );
      expect(tapped, [0]);
    });
  });

  group('player preview tooltip', () {
    testWidgets(
      'tapping player shows preview tooltip with stats and pair badge',
      (
        tester,
      ) async {
        const court = Court(
          id: 'c1',
          courtNumber: 1,
          status: CourtStatus.ready,
          currentPlayers: [
            SessionPlayer(
              id: 'p6',
              name: 'Nam',
              playerNumber: 6,
              position: 0,
              gender: Gender.male,
              level: 3, // TB-
            ),
            SessionPlayer(
              id: 'p1',
              name: 'Bình',
              playerNumber: 1,
              position: 1,
              gender: Gender.male,
              level: 3,
              matchesPlayed: 1,
              currentWaitTime: 15,
            ),
          ],
        );

        await pumpCourt(
          tester,
          const BadmintonCourtView(
            court: court,
            mode: CourtViewMode.manage,
          ),
        );

        // Tooltip is initially not visible
        expect(
          find.byKey(const Key('court-player-tooltip-card')),
          findsNothing,
        );

        // Tap player #6 (Nam)
        await tester.tap(find.text('Nam'));
        await tester.pumpAndSettle();

        // Tooltip is now visible
        expect(
          find.byKey(const Key('court-player-tooltip-card')),
          findsOneWidget,
        );
        expect(find.text('#6'), findsOneWidget);
        expect(find.text('Cặp 1'), findsOneWidget);
        expect(find.text('GIỚI TÍNH'), findsOneWidget);
        expect(find.text('TRÌNH ĐỘ'), findsOneWidget);
        expect(find.text('TRẬN ĐÃ CHƠI'), findsOneWidget);
        expect(find.text('THỜI GIAN CHỜ'), findsOneWidget);
        expect(find.text('TB-'), findsWidgets);
        expect(find.text('0p'), findsOneWidget);

        // Tapping outside dismisses the tooltip
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('court-player-tooltip-card')),
          findsNothing,
        );
      },
    );

    testWidgets('tapping same player toggles tooltip off', (tester) async {
      const court = Court(
        id: 'c1',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentPlayers: [
          SessionPlayer(
            id: 'p6',
            name: 'Nam',
            playerNumber: 6,
            position: 0,
          ),
        ],
      );

      await pumpCourt(
        tester,
        const BadmintonCourtView(court: court),
      );

      await tester.tap(find.byType(CourtPlayerMarker).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('court-player-tooltip-card')),
        findsOneWidget,
      );

      // Tap again to toggle off
      await tester.tap(find.byType(CourtPlayerMarker).first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('court-player-tooltip-card')),
        findsNothing,
      );
    });
  });
}
