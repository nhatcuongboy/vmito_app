import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/presentation/player/public_sessions_content.dart';
import 'package:vmito_app/features/session/presentation/widgets/session_card_skeleton.dart';
import 'package:vmito_app/l10n/app_localizations.dart';
import 'package:vmito_app/shared/widgets/app_loading_view.dart';

void main() {
  testWidgets('shows session card skeletons during the initial browse load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          browseSessionsControllerProvider.overrideWith(
            _LoadingBrowseSessionsController.new,
          ),
          locationPreferencesControllerProvider.overrideWith(
            _LocationPreferencesController.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: BrowseSessionsContent()),
        ),
      ),
    );

    expect(
      find.byKey(const Key('browse-sessions-skeleton-list')),
      findsOneWidget,
    );
    expect(find.byType(SessionCardSkeleton), findsAtLeastNWidgets(3));
    expect(find.byType(AppLoadingView), findsNothing);
  });
}

class _LoadingBrowseSessionsController extends BrowseSessionsController {
  @override
  BrowseSessionsState build() => const BrowseSessionsState(isLoading: true);

  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {}
}

class _LocationPreferencesController extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    selectionType: LocationSelectionType.city,
    onboardingCompleted: true,
    isRestored: true,
  );
}
