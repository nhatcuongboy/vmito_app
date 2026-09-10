import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/features/home/application/home_discovery_presets.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

void main() {
  ProviderContainer createContainer({
    VenueFilter venueFilter = const VenueFilter(),
  }) {
    final container = ProviderContainer(
      overrides: [
        locationPreferencesControllerProvider.overrideWith(
          _FixedLocationPreferences.new,
        ),
        venueBrowseControllerProvider.overrideWith(
          () => _FixedVenueController(venueFilter),
        ),
        browseSessionsControllerProvider.overrideWith(
          _RecordingSessionsController.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('sessions preset keeps only open sessions in the preferred city', () {
    final filters = createContainer()
        .read(homeDiscoveryPresetsProvider)
        .sessionFilters();

    expect(filters.city, 'Hồ Chí Minh');
    expect(filters.hasSlots, isTrue);
    expect(filters.sort, SessionBrowseSort.dateAsc);
    expect(filters.search, isEmpty);
  });

  test('venues fall back to the city list without a known position', () {
    final presets = createContainer().read(homeDiscoveryPresetsProvider);

    expect(
      presets.kindOf(HomeDiscoveryTab.venues),
      HomeFeaturedKind.venuesInCity,
    );
    expect(presets.venueFilter().sortBy, 'numberOfCourts');
    expect(presets.venueFilter().latitude, isNull);
  });

  test('venues sort by distance once the browse list has a position', () {
    final presets = createContainer(
      venueFilter: const VenueFilter(latitude: 10.77, longitude: 106.7),
    ).read(homeDiscoveryPresetsProvider);

    expect(
      presets.kindOf(HomeDiscoveryTab.venues),
      HomeFeaturedKind.venuesNearby,
    );
    expect(presets.venueFilter().sortBy, 'distance');
    expect(presets.venueFilter().latitude, 10.77);
  });

  test('applying the sessions preset replaces the browse filters', () async {
    final container = createContainer();
    await container
        .read(browseSessionsControllerProvider.notifier)
        .load(
          filters: const BrowseSessionFilters(search: 'cũ', levels: {3}),
        );

    await container
        .read(homeDiscoveryPresetsProvider)
        .apply(HomeDiscoveryTab.sessions);

    final filters = container.read(browseSessionsControllerProvider).filters;
    expect(filters.search, isEmpty);
    expect(filters.levels, isEmpty);
    expect(filters.hasSlots, isTrue);
  });
}

class _FixedLocationPreferences extends LocationPreferencesController {
  @override
  LocationPreferences build() => const LocationPreferences(
    preferredCity: 'Hồ Chí Minh',
    selectionType: LocationSelectionType.city,
    onboardingCompleted: true,
    isRestored: true,
  );
}

class _FixedVenueController extends VenueBrowseController {
  _FixedVenueController(this._filter);

  final VenueFilter _filter;

  @override
  VenueBrowseState build() => VenueBrowseState(filter: _filter);
}

class _RecordingSessionsController extends BrowseSessionsController {
  @override
  Future<void> load({String? search, BrowseSessionFilters? filters}) async {
    state = state.copyWith(filters: filters ?? state.filters);
  }
}
