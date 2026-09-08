import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/presentation/widgets/court_display_mode_switch.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/application/host_court_actions_state.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_actions.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  Widget app(Widget child) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('vi'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('display mode switch uses compact visual styling', (
    tester,
  ) async {
    await tester.pumpWidget(app(const CourtDisplayModeSwitch()));

    final switchFinder = find.byKey(const Key('court-display-mode-switch'));
    final switchWidget = tester.widget<SegmentedButton<dynamic>>(switchFinder);

    expect(switchFinder, findsOneWidget);
    expect(switchWidget.style?.minimumSize?.resolve({})?.height, 36);
    expect(switchWidget.style?.visualDensity, VisualDensity.compact);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('court card uses a compact number badge and layered shadow', (
    tester,
  ) async {
    const court = Court(id: 'court-2', courtNumber: 2);
    const session = Session(
      id: 'session-1',
      name: 'Kèo thử nghiệm',
      status: SessionStatus.inProgress,
      numberOfCourts: 1,
      maxPlayersPerCourt: 4,
    );

    await tester.pumpWidget(
      app(
        const SizedBox(
          width: 360,
          child: HostCourtCard(session: session, court: court),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('host-court-number-court-2'))),
      const Size.square(28),
    );

    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('host-court-card-surface-court-2')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.boxShadow, hasLength(2));
    expect(decoration.boxShadow!.first.blurRadius, 16);
    expect(decoration.boxShadow!.first.offset, const Offset(0, 6));
  });

  testWidgets('start action keeps its label and shows a spinner while busy', (
    tester,
  ) async {
    const court = Court(
      id: 'court-start',
      courtNumber: 1,
      status: CourtStatus.ready,
      currentPlayers: [SessionPlayer(id: 'player-1')],
    );

    await tester.pumpWidget(
      app(
        HostCourtActions(
          court: court,
          isSessionLive: true,
          waitingCount: 4,
          isBusy: true,
          activeAction: HostCourtAction.start,
          onAssign: () {},
          onClear: () {},
          onStart: () {},
          onPreSelect: () {},
          onViewNextMatch: () {},
          onEnd: () {},
        ),
      ),
    );

    final start = find.byKey(const ValueKey('start-court-start'));
    expect(
      find.descendant(of: start, matching: find.text('Bắt đầu')),
      findsOne,
    );
    expect(
      find.descendant(
        of: start,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOne,
    );
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey('clear-court-start')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'end action shows its own spinner without blocking another court',
    (
      tester,
    ) async {
      const busyCourt = Court(
        id: 'court-end',
        courtNumber: 1,
        status: CourtStatus.inUse,
        currentMatchId: 'match-1',
      );
      const availableCourt = Court(
        id: 'court-other',
        courtNumber: 2,
        status: CourtStatus.ready,
        currentPlayers: [SessionPlayer(id: 'player-2')],
      );

      await tester.pumpWidget(
        app(
          Column(
            children: [
              HostCourtActions(
                court: busyCourt,
                isSessionLive: true,
                waitingCount: 4,
                isBusy: true,
                activeAction: HostCourtAction.end,
                onAssign: () {},
                onClear: () {},
                onStart: () {},
                onPreSelect: () {},
                onViewNextMatch: () {},
                onEnd: () {},
              ),
              HostCourtActions(
                court: availableCourt,
                isSessionLive: true,
                waitingCount: 4,
                isBusy: false,
                activeAction: null,
                onAssign: () {},
                onClear: () {},
                onStart: () {},
                onPreSelect: () {},
                onViewNextMatch: () {},
                onEnd: () {},
              ),
            ],
          ),
        ),
      );

      final end = find.byKey(const ValueKey('end-court-end'));
      expect(
        find.descendant(of: end, matching: find.text('Kết thúc')),
        findsOne,
      );
      expect(
        find.descendant(
          of: end,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOne,
      );
      expect(tester.widget<FilledButton>(end).onPressed, isNull);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('start-court-other')),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('insufficient waiting players does not look like loading', (
    tester,
  ) async {
    const court = Court(id: 'court-empty', courtNumber: 3);

    await tester.pumpWidget(
      app(
        HostCourtActions(
          court: court,
          isSessionLive: true,
          waitingCount: 2,
          isBusy: false,
          activeAction: null,
          onAssign: () {},
          onClear: () {},
          onStart: () {},
          onPreSelect: () {},
          onViewNextMatch: () {},
          onEnd: () {},
        ),
      ),
    );

    final assign = find.byKey(const ValueKey('assign-court-empty'));
    expect(tester.widget<FilledButton>(assign).onPressed, isNull);
    expect(
      find.descendant(
        of: assign,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );
  });
}
