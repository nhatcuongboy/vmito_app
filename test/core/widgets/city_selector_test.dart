import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/device_geocoding_service.dart';
import 'package:vmito_app/core/location/device_location_service.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/core/location/new_admin_units.dart';
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
  Future<void> selectCity(String? city) async {
    state = state.copyWith(
      preferredCity: city,
      clearPreferredCity: city == null,
      onboardingCompleted: true,
    );
  }
}

Widget _app({
  required ValueChanged<String?> onChanged,
  DeviceReverseGeocoder? geocoder,
}) => ProviderScope(
  overrides: [
    locationPreferencesControllerProvider.overrideWith(
      () => _PreferencesController(
        const LocationPreferences(
          preferredCity: 'Hồ Chí Minh',
          onboardingCompleted: true,
          isRestored: true,
        ),
      ),
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
      appBar: AppBar(title: CitySelector(onChanged: onChanged)),
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
    expect(find.byKey(const Key('city-selector-search')), findsOneWidget);
    expect(find.byIcon(AppIcons.checkCircle), findsOneWidget);
    expect(find.text('Phổ biến'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byKey(const Key('city-selector-results')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tất cả tỉnh / thành phố'), findsOneWidget);

    await tester.tap(find.byKey(const Key('city-selector-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('city-selector-search')), findsNothing);
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
      lessThanOrEqualTo(600),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('searches without tones and returns the selected city', (
    tester,
  ) async {
    String? changed;
    await tester.pumpWidget(_app(onChanged: (city) => changed = city));

    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('city-selector-search')),
        matching: find.byType(TextField),
      ),
      'da nang',
    );
    await tester.pump();

    expect(find.text('Đà Nẵng'), findsOneWidget);
    expect(find.byKey(const Key('discovery-city-all')), findsNothing);
    await tester.tap(find.text('Đà Nẵng'));
    await tester.pumpAndSettle();

    expect(changed, 'Đà Nẵng');
    expect(find.byIcon(AppIcons.location), findsOneWidget);
  });

  testWidgets('uses device placemark to select a city', (tester) async {
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
    await tester.tap(find.byKey(const Key('city-selector-current-location')));
    await tester.pumpAndSettle();

    expect(changed, 'Hà Nội');
  });

  testWidgets('selecting all reports an intentional null city', (tester) async {
    var wasCalled = false;
    String? changed = 'not-null';
    await tester.pumpWidget(
      _app(
        onChanged: (city) {
          wasCalled = true;
          changed = city;
        },
      ),
    );

    await tester.tap(find.byKey(const Key('discovery-city-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('discovery-city-all')));
    await tester.pumpAndSettle();

    expect(wasCalled, isTrue);
    expect(changed, isNull);
    expect(find.byIcon(AppIcons.location), findsOneWidget);
  });

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
    expect(find.byKey(const Key('city-selector-results')), findsOneWidget);
  });
}
