import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/court_call_dialog.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  testWidgets('renders the court name, title, and acknowledge CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CourtCallDialog.show(
              context,
              courtDisplayName: 'Sân 5',
              onAcknowledge: () {},
            ),
            child: const Text('trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();

    expect(find.text('Đến lượt bạn vào sân!'), findsOneWidget);
    expect(find.text('Sân 5'), findsOneWidget);
    expect(find.text('Đã hiểu, tôi đang đến!'), findsOneWidget);
  });

  testWidgets('is not dismissed by the Android back gesture', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CourtCallDialog.show(
              context,
              courtDisplayName: 'Sân 5',
              onAcknowledge: () {},
            ),
            child: const Text('trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    // maybePop returns true whenever the pop is *handled* — including a
    // PopScope(canPop: false) route that intercepts and denies it — so the
    // real assertion is that the dialog is still on screen afterwards.
    await navigator.maybePop();
    await tester.pump();

    expect(find.text('Sân 5'), findsOneWidget);
  });

  testWidgets('acknowledge button pops the dialog and calls back', (
    tester,
  ) async {
    var acknowledged = false;

    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CourtCallDialog.show(
              context,
              courtDisplayName: 'Sân 5',
              onAcknowledge: () => acknowledged = true,
            ),
            child: const Text('trigger'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger'));
    await tester.pump();

    await tester.tap(find.text('Đã hiểu, tôi đang đến!'));
    await tester.pumpAndSettle();

    expect(acknowledged, isTrue);
    expect(find.text('Sân 5'), findsNothing);
  });
}
