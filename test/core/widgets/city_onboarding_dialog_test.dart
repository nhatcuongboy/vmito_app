import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/city_selector.dart';
import 'package:vmito_app/core/widgets/city_selector_sheet.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

class _PreferencesController extends LocationPreferencesController {
  _PreferencesController(this.initial);

  final LocationPreferences initial;

  @override
  LocationPreferences build() => initial;

  @override
  Future<void> selectCity(String? city, {Set<String> wards = const {}}) async {
    state = state.copyWith(
      preferredCity: city,
      clearPreferredCity: city == null,
      preferredWards: wards,
      selectionType: city == null
          ? LocationSelectionType.all
          : LocationSelectionType.city,
      onboardingCompleted: true,
    );
  }

  @override
  Future<void> selectAll() async {
    state = state.copyWith(
      clearPreferredCity: true,
      preferredWards: const {},
      selectionType: LocationSelectionType.all,
      onboardingCompleted: true,
    );
  }

  @override
  Future<void> selectOther() async {
    state = state.copyWith(
      clearPreferredCity: true,
      preferredWards: const {},
      selectionType: LocationSelectionType.other,
      onboardingCompleted: true,
    );
  }
}

void main() {
  testWidgets(
    'onboarding uses selector content and hides the close button',
    (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationPreferencesControllerProvider.overrideWith(
              () => _PreferencesController(
                const LocationPreferences(
                  isRestored: true,
                ),
              ),
            ),
            newAdminUnitsProvider.overrideWith(
              (ref) async => const [
                NewAdminUnit(city: 'Thành phố Hồ Chí Minh', wards: []),
                NewAdminUnit(city: 'Thành phố Hà Nội', wards: []),
                NewAdminUnit(city: 'Thành phố Đà Nẵng', wards: []),
              ],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('vi'),
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () =>
                        CityOnboardingDialog.maybeShow(context, ref),
                    child: const Text('Open Onboarding'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Onboarding'));
      await tester.pumpAndSettle();

      // Uses the unified title and the onboarding subtitle
      expect(find.text('Chọn khu vực của bạn'), findsOneWidget);
      expect(
        find.text('Chọn thành phố để xem các kèo và sân gần bạn nhất.'),
        findsOneWidget,
      );

      // No close button in sheet header during onboarding
      expect(find.byKey(const Key('city-selector-close')), findsNothing);

      // Province field, current-location action, and "other area" button
      expect(
        find.byKey(const Key('city-selector-province-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('city-selector-current-location')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('city-selector-other')), findsOneWidget);

      // Footer has Reset and Apply
      expect(find.byKey(const Key('city-selector-reset')), findsOneWidget);
      expect(find.byKey(const Key('city-selector-apply')), findsOneWidget);
    },
  );

  testWidgets('selecting Khác completes onboarding with Other selection', (
    tester,
  ) async {
    CitySelection? result;
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            () => _PreferencesController(
              const LocationPreferences(
                isRestored: true,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await CityOnboardingDialog.maybeShow(
                        context,
                        ref,
                      );
                    },
                    child: const Text('Open Onboarding'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Onboarding'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('city-selector-other')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-selector-apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.type, LocationSelectionType.other);
    expect(result?.city, isNull);

    final pref = capturedRef.read(locationPreferencesControllerProvider);
    expect(pref.onboardingCompleted, isTrue);
    expect(pref.selectionType, LocationSelectionType.other);
    expect(pref.preferredCity, isNull);
  });

  testWidgets('picking a city completes onboarding with city selection', (
    tester,
  ) async {
    CitySelection? result;
    late WidgetRef capturedRef;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationPreferencesControllerProvider.overrideWith(
            () => _PreferencesController(
              const LocationPreferences(
                isRestored: true,
              ),
            ),
          ),
          newAdminUnitsProvider.overrideWith(
            (ref) async => const [
              NewAdminUnit(city: 'Thành phố Đà Nẵng', wards: []),
            ],
          ),
        ],
        child: MaterialApp(
          locale: const Locale('vi'),
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () async {
                      result = await CityOnboardingDialog.maybeShow(
                        context,
                        ref,
                      );
                    },
                    child: const Text('Open Onboarding'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Onboarding'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('city-selector-province-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Đà Nẵng'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-selector-apply')));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.type, LocationSelectionType.city);
    expect(result?.city, 'Đà Nẵng');

    final pref = capturedRef.read(locationPreferencesControllerProvider);
    expect(pref.onboardingCompleted, isTrue);
    expect(pref.selectionType, LocationSelectionType.city);
    expect(pref.preferredCity, 'Đà Nẵng');
  });
}
