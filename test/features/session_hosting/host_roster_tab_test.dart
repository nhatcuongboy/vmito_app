import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_spacing.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
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

  Widget subject() => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: HostRosterTab(session: session)),
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

  testWidgets('uses compact player controls and cards on mobile', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(subject());

    final grid = tester.widget<GridView>(
      find.byKey(const Key('host-roster-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, 124);

    expect(
      tester.getRect(find.byType(TextField)).height,
      AppSizes.minTapTarget,
    );
    expect(
      tester.getRect(find.byKey(const Key('host-roster-filter'))).height,
      greaterThanOrEqualTo(AppSizes.minTapTarget),
    );
    expect(
      tester.getRect(find.byKey(const Key('host-roster-add'))).height,
      greaterThanOrEqualTo(AppSizes.minTapTarget),
    );
  });

  testWidgets('filters roster using the search field', (tester) async {
    await tester.pumpWidget(subject());

    await tester.enterText(find.byType(TextField), 'Minh');
    await tester.pump();

    expect(find.text('Minh'), findsNWidgets(2));
    expect(find.text('Sơn'), findsNothing);
  });
}
