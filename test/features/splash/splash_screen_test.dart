import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/widgets/app_logo.dart';
import 'package:vmito_app/features/splash/presentation/splash_screen.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  testWidgets('SplashScreen renders AppLogo and loading indicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('vi'),
        home: SplashScreen(),
      ),
    );
    await tester.pump();

    // Verify AppLogo is rendered
    expect(find.byType(AppLogo), findsOneWidget);

    // Verify progress indicator is rendered
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
