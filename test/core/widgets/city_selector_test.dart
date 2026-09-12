import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/device_geocoding_service.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
import 'package:vmito_app/core/theme/app_colors.dart';
import 'package:vmito_app/core/theme/app_icons.dart';
import 'package:vmito_app/core/theme/app_theme.dart';
import 'package:vmito_app/core/widgets/city_selector.dart';
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

Widget _app({
  required ValueChanged<String?> onChanged,
  DeviceReverseGeocoder? geocoder,
  LocationPreferences initialPreferences = const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    selectionType: LocationSelectionType.city,
    onboardingCompleted: true,
    isRestored: true,
  ),
  bool showLabel = false,
}) => ProviderScope(
  overrides: [
    locationPreferencesControllerProvider.overrideWith(
      () => _PreferencesController(initialPreferences),
    ),
    newAdminUnitsProvider.overrideWith(
      (ref) async => const [
        NewAdminUnit(city: 'Thành phố Hồ Chí Minh', wards: []),
        NewAdminUnit(city: 'Thành phố Hà Nội', wards: []),
        NewAdminUnit(city: 'Thành phố Đà Nẵng', wards: []),
        NewAdminUnit(city: 'Tỉnh An Giang', wards: []),
      ],
    ),
    deviceLocationServiceProvider.overrideWithValue(
      () async => const DeviceCoordinates(latitude: 21, longitude: 105),
    ),
    if (geocoder != null)
      deviceReverseGeocoderProvider.overrideWithValue(geocoder),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: const Locale('vi'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      appBar: AppBar(
        title: CitySelector(
          onChanged: (city, _) => onChanged(city),
          showLabel: showLabel,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('renders a compact, actionable sheet without overflow', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(onChanged: (_) {}));
    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('city-selector-close')), findsOneWidget);
    expect(
      find.byKey(const Key('city-selector-current-location')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('city-selector-province-field')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('city-selector-ward-field')), findsOneWidget);
    expect(find.text('Phổ biến'), findsOneWidget);
    expect(find.byKey(const Key('city-selector-other')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('city-selector-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('city-selector-province-field')), findsNothing);
  });

  testWidgets('constrains sheet content on wide windows', (tester) async {
    tester.view
      ..physicalSize = const Size(1000, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(onChanged: (_) {}));
    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(find.byKey(const Key('city-selector-sheet-content')))
          .width,
      lessThanOrEqualTo(640),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'searches without tones and picks a city from the province picker',
    (
      tester,
    ) async {
      String? changed;
      await tester.pumpWidget(_app(onChanged: (city) => changed = city));

      await tester.tap(find.byKey(const Key('discovery-city-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('city-selector-province-field')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'da nang');
      await tester.pump();

      expect(find.widgetWithText(ListTile, 'Đà Nẵng'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Đà Nẵng'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('city-selector-province-field')),
          matching: find.text('Đà Nẵng'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('city-selector-apply')));
      await tester.pumpAndSettle();

      expect(changed, 'Đà Nẵng');
    },
  );

  testWidgets(
    'uses device placemark to fill the province without closing the sheet',
    (tester) async {
      String? changed;
      await tester.pumpWidget(
        _app(
          onChanged: (city) => changed = city,
          geocoder: (_) async => const DevicePlacemark([
            'Thành phố Hà Nội',
          ]),
        ),
      );

      await tester.tap(find.byKey(const Key('discovery-city-selector')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('city-selector-current-location')),
      );
      await tester.pumpAndSettle();

      // Fills the province field but keeps the sheet open.
      expect(
        find.descendant(
          of: find.byKey(const Key('city-selector-province-field')),
          matching: find.text('Hà Nội'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('city-selector-apply')), findsOneWidget);
      expect(changed, isNull);

      await tester.tap(find.byKey(const Key('city-selector-apply')));
      await tester.pumpAndSettle();

      expect(changed, 'Hà Nội');
    },
  );

  testWidgets('reset then apply reports an intentional null city', (
    tester,
  ) async {
    String? changed = 'not-null';
    await tester.pumpWidget(_app(onChanged: (city) => changed = city));

    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-selector-reset')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-selector-apply')));
    await tester.pumpAndSettle();

    expect(changed, isNull);
  });

  testWidgets(
    'selecting Khu vực khác reports an intentional null city and updates label',
    (tester) async {
      var wasCalled = false;
      String? changed = 'not-null';
      await tester.pumpWidget(
        _app(
          showLabel: true,
          onChanged: (city) {
            wasCalled = true;
            changed = city;
          },
        ),
      );

      expect(find.text('Hồ Chí Minh'), findsOneWidget);

      await tester.tap(find.byKey(const Key('discovery-city-selector')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('city-selector-other')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('city-selector-apply')));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(changed, isNull);
      expect(find.text('Khu vực khác'), findsOneWidget);
    },
  );

  testWidgets('keeps the sheet open and reports a geocoding failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        onChanged: (_) {},
        geocoder: (_) async => throw const DeviceGeocodingException(),
      ),
    );

    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-selector-current-location')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('city-selector-location-error')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('city-selector-apply')), findsOneWidget);
  });

  testWidgets(
    'GPS abroad outside the supported list falls back to Other after Apply',
    (tester) async {
      var wasCalled = false;
      String? changed = 'not-null';
      await tester.pumpWidget(
        _app(
          onChanged: (city) {
            wasCalled = true;
            changed = city;
          },
          geocoder: (_) async => const DevicePlacemark([
            'Tokyo',
            'Japan',
          ]),
        ),
      );

      await tester.tap(find.byKey(const Key('discovery-city-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('city-selector-current-location')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('city-selector-location-error')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('city-selector-apply')));
      await tester.pumpAndSettle();

      expect(wasCalled, isTrue);
      expect(changed, isNull);
    },
  );

  testWidgets(
    'shows chevron down icon and uses green primary color when non-All option is selected',
    (tester) async {
      await tester.pumpWidget(
        _app(
          initialPreferences: const LocationPreferences(
            preferredCity: 'Hồ Chí Minh',
            selectionType: LocationSelectionType.city,
            onboardingCompleted: true,
            isRestored: true,
          ),
          showLabel: true,
          onChanged: (_) {},
        ),
      );

      final buttonFinder = find.byKey(const Key('discovery-city-selector'));
      expect(buttonFinder, findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);

      final button = tester.widget<OutlinedButton>(buttonFinder);
      expect(
        button.style?.foregroundColor?.resolve({}),
        AppTheme.light.colorScheme.primary,
      );
    },
  );

  testWidgets(
    'uses muted foreground color when All option is selected',
    (tester) async {
      await tester.pumpWidget(
        _app(
          initialPreferences: const LocationPreferences(
            selectionType: LocationSelectionType.all,
            onboardingCompleted: true,
            isRestored: true,
          ),
          showLabel: true,
          onChanged: (_) {},
        ),
      );

      final buttonFinder = find.byKey(const Key('discovery-city-selector'));
      expect(buttonFinder, findsOneWidget);
      expect(find.byIcon(AppIcons.chevronDown), findsOneWidget);

      final button = tester.widget<OutlinedButton>(buttonFinder);
      expect(
        button.style?.foregroundColor?.resolve({}),
        AppTheme.light.extension<AppPalette>()!.mutedForeground,
      );
    },
  );
}
