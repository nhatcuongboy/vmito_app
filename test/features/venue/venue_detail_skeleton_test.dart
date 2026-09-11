import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/venue/presentation/venue_detail_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('renders venue detail skeleton in ${theme.brightness} mode', (
      tester,
    ) async {
      tester.view
        ..physicalSize = const Size(390, 844)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VenueDetailSkeleton(),
        ),
      );

      expect(find.byKey(const Key('venue-detail-skeleton')), findsOneWidget);
      expect(find.byKey(const Key('venue-back-button')), findsOneWidget);
      expect(find.byType(Shimmer), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'back button stays functional so a slow request cannot trap the user',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const VenueDetailSkeleton(),
        ),
      );

      final button = tester.widget<IconButton>(find.byType(IconButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets('keeps the card layout overflow-free on a narrow phone', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const VenueDetailSkeleton(),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
