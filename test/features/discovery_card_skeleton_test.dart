import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/social/presentation/club_browse_card_skeleton.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_browse_card_skeleton.dart';
import 'package:vmito_app/features/venue/presentation/venue_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

void main() {
  for (final theme in <ThemeData>[AppTheme.light, AppTheme.dark]) {
    testWidgets('discovery card skeletons render in ${theme.brightness} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  VenueCardSkeleton(),
                  ClubBrowseCardSkeleton(),
                  TournamentBrowseCardSkeleton(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byType(Shimmer), findsNWidgets(3));
      expect(find.byKey(const Key('venue-skeleton-logo')), findsOneWidget);
      expect(find.byKey(const Key('club-skeleton-logo')), findsOneWidget);
      expect(
        find.byKey(const Key('tournament-skeleton-status')),
        findsOneWidget,
      );
    });
  }
}
