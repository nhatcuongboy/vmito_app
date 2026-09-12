import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/features/tournament/presentation/tournament_browse_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestLocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(isRestored: true);
}

void main() {
  testWidgets('shows tournament card skeletons during the first load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            _TestLocationPreferencesController.new,
          ),
          tournamentBrowseControllerProvider.overrideWith(
            _LoadingTournamentsController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: BrowseTournamentsContent(showMapToggle: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('tournament-skeleton-list')), findsOneWidget);
    expect(
      find.byType(TournamentBrowseCardSkeleton),
      findsAtLeastNWidgets(3),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const Key('tournament-map-view-toggle')), findsOneWidget);
  });

  testWidgets(
    'tournament card wires its favorite button and hides it for guests',
    (
      tester,
    ) async {
      final tournament = TournamentSummary(
        id: 'tournament-1',
        name: 'Giải mùa thu',
        startDate: DateTime.utc(2026, 9),
        endDate: DateTime.utc(2026, 9, 2),
        status: TournamentStatus.preparing,
        isPublished: true,
        isFavorite: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSignedInProvider.overrideWithValue(false),
            locationPreferencesControllerProvider.overrideWith(
              _TestLocationPreferencesController.new,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: TournamentBrowseCard(tournament: tournament)),
          ),
        ),
      );

      final favorite = tester.widget<FavoriteButton>(
        find.byType(FavoriteButton),
      );
      expect(favorite.type, FavoriteType.tournament);
      expect(favorite.targetId, 'tournament-1');
      expect(favorite.initialIsFavorite, isTrue);
      expect(favorite.variant, FavoriteButtonVariant.card);
      expect(favorite.showCount, isFalse);
      expect(find.byIcon(AppIcons.favoriteFilled), findsNothing);
    },
  );
}

class _LoadingTournamentsController extends TournamentBrowseController {
  @override
  TournamentBrowseState build() => const TournamentBrowseState(isLoading: true);

  @override
  Future<void> load({
    String? search,
    String? city,
    bool clearCity = false,
    Set<TournamentStatus>? statuses,
    Set<String>? sportTypes,
    bool? favoriteOnly,
    TournamentBrowseSort? sort,
    bool isPullToRefresh = false,
  }) async {}
}
