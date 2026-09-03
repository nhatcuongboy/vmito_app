import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';
import 'package:vmito_app/features/favorite/presentation/favorite_button.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/tournament/presentation/browse_tournaments_content.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _TestLocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(isRestored: true);
}

void main() {
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
