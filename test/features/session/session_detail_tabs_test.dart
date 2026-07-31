import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/application/session_detail_controller.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/features/session/presentation/session_detail_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('switches between overview, courts and players tabs', (
    tester,
  ) async {
    const session = Session(
      id: 's1',
      name: 'Sunday Smash',
      status: SessionStatus.inProgress,
      numberOfCourts: 1,
      maxPlayersPerCourt: 4,
      courts: [Court(id: 'c1', courtNumber: 1)],
      players: [SessionPlayer(id: 'p1', name: 'Linh', level: 4)],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionDetailProvider.overrideWith((ref, id) async => session),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SessionDetailScreen(sessionId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Courts'), findsOneWidget);
    expect(find.text('Players'), findsOneWidget);

    await tester.tap(find.text('Players'));
    await tester.pumpAndSettle();
    expect(find.text('Linh'), findsOneWidget);
    expect(find.text('TB'), findsOneWidget);
  });
}
