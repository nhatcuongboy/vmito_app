import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/social/presentation/widgets/feed_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('renders feed skeleton in ${theme.brightness} mode', (
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
          home: const Scaffold(body: FeedSkeleton()),
        ),
      );

      expect(find.byKey(const Key('feed-skeleton-list')), findsOneWidget);
      // Two `AppShimmer`s per `SocialPostCardSkeleton` row (header/body +
      // action bar), sized between `minItems` and `maxItems` rows.
      final shimmerCount = tester.widgetList(find.byType(Shimmer)).length;
      expect(shimmerCount, inInclusiveRange(4, 10));
      expect(shimmerCount.isEven, isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps the layout overflow-free on a narrow phone', (
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
        home: const Scaffold(body: FeedSkeleton()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
