import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/host_roster_tab.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/session_player.dart';

void main() {
  const session = Session(
    id: 'session-1',
    name: 'Kèo test',
    status: SessionStatus.preparing,
    numberOfCourts: 2,
    maxPlayersPerCourt: 4,
    players: [
      SessionPlayer(
        id: 'p-1',
        name: 'Sơn',
        playerNumber: 1,
        level: 4,
        matchesPlayed: 10,
      ),
      SessionPlayer(
        id: 'p-2',
        name: 'Minh',
        playerNumber: 2,
        level: 5,
        status: PlayerStatus.playing,
        matchesPlayed: 9,
      ),
    ],
  );

  Widget subject() => const ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: HostRosterTab(session: session)),
    ),
  );

  testWidgets('renders web-equivalent roster header and grid controls', (
    tester,
  ) async {
    await tester.pumpWidget(subject());

    expect(find.text('Người chơi (2/8)'), findsOneWidget);
    expect(find.byKey(const Key('host-roster-add')), findsOneWidget);
    expect(find.byKey(const Key('host-roster-filter')), findsOneWidget);
    expect(find.text('Sơn'), findsOneWidget);
    expect(find.text('Minh'), findsOneWidget);
  });

  testWidgets('filters roster using the search field', (tester) async {
    await tester.pumpWidget(subject());

    await tester.enterText(find.byType(TextField), 'Minh');
    await tester.pump();

    expect(find.text('Minh'), findsNWidgets(2));
    expect(find.text('Sơn'), findsNothing);
  });
}
