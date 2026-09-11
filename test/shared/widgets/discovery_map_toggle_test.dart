import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/discovery_map_toggle.dart';

void main() {
  Widget buildSubject({
    required bool showMap,
    required VoidCallback onPressed,
    bool isExtended = true,
  }) => MaterialApp(
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Scaffold(
      body: Center(
        child: DiscoveryMapToggle(
          showMap: showMap,
          onPressed: onPressed,
          isExtended: isExtended,
        ),
      ),
    ),
  );

  testWidgets('DiscoveryMapToggle displays label and icon when extended', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showMap: false,
        onPressed: () {},
        isExtended: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.byIcon(AppIcons.mapPin), findsOneWidget);
    expect(tester.getSize(find.byType(DiscoveryMapToggle)).height, 44);
  });

  testWidgets('DiscoveryMapToggle displays list label and icon when showMap is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showMap: true,
        onPressed: () {},
        isExtended: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Danh sách'), findsOneWidget);
    expect(find.byIcon(AppIcons.list), findsOneWidget);
    expect(tester.getSize(find.byType(DiscoveryMapToggle)).height, 44);
  });

  testWidgets('DiscoveryMapToggle hides label when collapsed (isExtended = false)', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(
        showMap: false,
        onPressed: () {},
        isExtended: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bản đồ'), findsNothing);
    expect(find.byIcon(AppIcons.mapPin), findsOneWidget);
    expect(tester.getSize(find.byType(DiscoveryMapToggle)).height, 44);
  });

  testWidgets('DiscoveryMapToggle invokes onPressed callback when tapped', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      buildSubject(
        showMap: false,
        onPressed: () => pressed = true,
        isExtended: true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DiscoveryMapToggle));
    expect(pressed, isTrue);
  });
}
