import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/presentation/player/detail/session_detail_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('renders session detail skeleton in ${theme.brightness} mode', (
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
          home: const Scaffold(body: SessionDetailSkeleton()),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(
        find.byKey(const Key('session-detail-skeleton-hero')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('session-detail-skeleton-content')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('session-detail-skeleton-back')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('session-detail-skeleton-host-avatar')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps the richer layout overflow-free on a narrow phone', (
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
        home: const Scaffold(body: SessionDetailSkeleton()),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
