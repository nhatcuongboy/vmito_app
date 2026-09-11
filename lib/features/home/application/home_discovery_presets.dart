import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

/// Which featured list a tab shows; decides the section title.
enum HomeFeaturedKind {
  sessionsWithSlots,
  venuesNearby,
  venuesInCity,
  clubsActive,
  tournamentsUpcoming,
}

/// The featured list behind each tab's search screen.
///
/// The search screen previews a preset and "see all" applies the same preset
/// to the browse list, so both read their parameters from here. A preset
/// replaces the user's filters rather than merging with them: the preview
/// promised a specific list, and Home snapshots the previous browse state so
/// leaving the preset restores it.
class HomeDiscoveryPresets {
  const HomeDiscoveryPresets(this._ref);

  static const clubSort = 'sessionCount';
  static const Set<TournamentStatus> tournamentStatuses = {
    TournamentStatus.preparing,
  };
  static const TournamentBrowseSort tournamentSort =
      TournamentBrowseSort.startAsc;

  final Ref _ref;

  String? get city =>
      _ref.read(locationPreferencesControllerProvider).preferredCity;

  HomeFeaturedKind kindOf(HomeDiscoveryTab tab) => switch (tab) {
    HomeDiscoveryTab.sessions => HomeFeaturedKind.sessionsWithSlots,
    HomeDiscoveryTab.venues when _knownVenueLocation != null =>
      HomeFeaturedKind.venuesNearby,
    HomeDiscoveryTab.venues => HomeFeaturedKind.venuesInCity,
    HomeDiscoveryTab.clubs => HomeFeaturedKind.clubsActive,
    HomeDiscoveryTab.tournaments => HomeFeaturedKind.tournamentsUpcoming,
  };

  BrowseSessionFilters sessionFilters() =>
      BrowseSessionFilters(city: city, hasSlots: true);

  /// Nearest venues only when the browse list already holds a position —
  /// the search screen must not raise a location permission prompt.
  VenueFilter venueFilter() => switch (_knownVenueLocation) {
    (final latitude, final longitude) => VenueFilter(
      city: city,
      latitude: latitude,
      longitude: longitude,
    ),
    null => VenueFilter(city: city, sortBy: 'numberOfCourts'),
  };

  (double, double)? get _knownVenueLocation {
    final filter = _ref.read(venueBrowseControllerProvider).filter;
    return switch ((filter.latitude, filter.longitude)) {
      (final double latitude, final double longitude) => (latitude, longitude),
      _ => null,
    };
  }

  Future<void> apply(HomeDiscoveryTab tab) => switch (tab) {
    HomeDiscoveryTab.sessions =>
      _ref
          .read(browseSessionsControllerProvider.notifier)
          .load(filters: sessionFilters()),
    HomeDiscoveryTab.venues =>
      _ref
          .read(venueBrowseControllerProvider.notifier)
          .load(filter: venueFilter()),
    HomeDiscoveryTab.clubs =>
      _ref
          .read(clubsControllerProvider.notifier)
          .load(
            filters: ClubBrowseFilters(city: city),
            sortBy: clubSort,
          ),
    HomeDiscoveryTab.tournaments =>
      _ref
          .read(tournamentBrowseControllerProvider.notifier)
          .load(
            search: '',
            city: city,
            clearCity: city == null,
            statuses: tournamentStatuses,
            sportTypes: const {},
            favoriteOnly: false,
            sort: tournamentSort,
          ),
  };
}

final homeDiscoveryPresetsProvider = Provider<HomeDiscoveryPresets>(
  HomeDiscoveryPresets.new,
);
