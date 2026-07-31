import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/features/live_session/presentation/widgets/badminton_court_view.dart';
import 'package:vmito_app/features/session/domain/court.dart';
import 'package:vmito_app/features/session/domain/session_player.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final locale in const [Locale('vi'), Locale('en'), Locale('zh')]) {
    testWidgets(
      'renders a responsive court and players in ${locale.languageCode}',
      (
        tester,
      ) async {
        const court = Court(
          id: 'court-1',
          courtNumber: 1,
          status: CourtStatus.inUse,
          currentPlayers: [
            SessionPlayer(id: 'p1', name: 'An'),
            SessionPlayer(id: 'p2', name: 'Bình'),
            SessionPlayer(id: 'p3', playerNumber: 3),
            SessionPlayer(id: 'p4', name: 'Dũng'),
          ],
        );

        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
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
      },
    );
  }
}
