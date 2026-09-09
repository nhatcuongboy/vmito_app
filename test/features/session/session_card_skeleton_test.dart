import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('renders browse skeleton in ${theme.brightness} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SessionCardSkeleton(
              variant: SessionCardVariant.browse,
              showFavorite: true,
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsOneWidget);
      expect(
        find.byKey(const Key('session-card-skeleton-host')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('session-card-skeleton-favorite')),
        findsOneWidget,
      );
    });
  }

  testWidgets('standard skeleton can match a hosted management card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SessionCardSkeleton(showHostInfo: false, showActions: true),
        ),
      ),
    );

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byKey(const Key('session-card-skeleton-host')), findsNothing);
  });
}
