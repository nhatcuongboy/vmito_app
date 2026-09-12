import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/leaderboard_podium.dart';
import 'package:vmito_app/features/leaderboard/presentation/widgets/rank_pulse_glow.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('lays the podium out 2-1-3 with the champion widest', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    final order = tester
        .widgetList<InkWell>(find.byType(InkWell))
        .map((widget) => widget.key)
        .whereType<ValueKey<String>>()
        .map((key) => key.value)
        .toList();
    expect(order, [
      'leaderboard-podium-2',
      'leaderboard-podium-1',
      'leaderboard-podium-3',
    ]);

    final champion = tester.getSize(_podium(1)).width;
    final runnerUp = tester.getSize(_podium(2)).width;
    expect(champion, greaterThan(runnerUp));

    // The pedestal step: 2nd and 3rd sit lower than the champion.
    expect(
      tester.getTopLeft(_podium(2)).dy,
      greaterThan(tester.getTopLeft(_podium(1)).dy),
    );
  });

  testWidgets('marks the signed-in user on their podium card', (tester) async {
    await tester.pumpWidget(_app(currentUserId: 'u1'));
    await tester.pump();

    expect(find.text('You'), findsOneWidget);
    expect(find.byType(RankPulseGlow), findsOneWidget);
  });

  testWidgets('marks nobody when the viewer is signed out', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pump();

    expect(find.text('You'), findsNothing);
    expect(find.byType(RankPulseGlow), findsNothing);
  });

  testWidgets('stacks full-width cards at large text scale', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_app());
    await tester.pump();

    expect(
      tester.getSize(_podium(1)).width,
      tester.getSize(_podium(2)).width,
    );
    expect(tester.takeException(), isNull);
  });
}

Finder _podium(int rank) => find.byKey(ValueKey('leaderboard-podium-$rank'));

Widget _app({String? currentUserId}) => MaterialApp(
  locale: const Locale('en'),
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: SingleChildScrollView(
      child: LeaderboardPodium(
        entries: [_entry('u1', 1), _entry('u2', 2), _entry('u3', 3)],
        period: LeaderboardPeriod.week,
        currentUserId: currentUserId,
        onTap: (_) {},
      ),
    ),
  ),
);

LeaderboardEntry _entry(String id, int rank) => LeaderboardEntry(
  rank: rank,
  points: 300 - rank * 10,
  user: LeaderboardUser(id: id, name: 'Player $rank'),
  tier: RankingTier.gold,
  totalPoints: 1657,
  matchesWon: 15,
  matchesPlayed: 23,
);
