import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/court/presentation/widgets/court_display_mode_switch.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/session_hosting/presentation/widgets/court/host_court_card.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/models/court.dart';

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
}
