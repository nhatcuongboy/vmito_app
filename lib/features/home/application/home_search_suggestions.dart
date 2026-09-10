// The family provider's type is whatever `FutureProvider.autoDispose.family`
// returns; spelling it out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/features/home/application/home_discovery_presets.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_controller.dart';
import 'package:vmito_app/features/session/application/player/browse_sessions_query.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';
import 'package:vmito_app/features/social/application/social_controller.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club.dart';
import 'package:vmito_app/features/tournament/application/tournament_browse_controller.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';
import 'package:vmito_app/features/venue/application/venue_controller.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

// Kept as a boundary so widget tests can supply deterministic suggestions.
abstract interface class HomeSearchSuggestionService {
  /// Page 1 of what submitting [query] would show on the browse list.
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
  });

  /// A short preview of the tab's preset (see [HomeDiscoveryPresets]).
  Future<List<DiscoverySuggestion>> featured(HomeDiscoveryTab tab);
}

class ApiHomeSearchSuggestionService implements HomeSearchSuggestionService {
  const ApiHomeSearchSuggestionService(this._ref);

  static const _searchLimit = 5;
  static const _featuredLimit = 4;

  final Ref _ref;

  HomeDiscoveryPresets get _presets => _ref.read(homeDiscoveryPresetsProvider);

  bool get _showNewAddress =>
      _ref.read(locationPreferencesControllerProvider).showNewAddress;

  // Each query mirrors `HomeScreen._applySearch`: the current browse filters
  // plus the keyword. A suggestion the result list would omit is a broken
  // promise.
  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
  }) async => switch (tab) {
    HomeDiscoveryTab.sessions => _sessions(
      _ref
          .read(browseSessionsControllerProvider)
          .filters
          .copyWith(
            search: query,
          ),
      _searchLimit,
    ),
    HomeDiscoveryTab.venues => _venues(
      _ref
          .read(venueBrowseControllerProvider)
          .filter
          .copyWith(keyword: query, sortBy: 'relevance'),
      _searchLimit,
    ),
    HomeDiscoveryTab.clubs => _clubs(
      _ref.read(clubsControllerProvider),
      search: query,
      limit: _searchLimit,
    ),
    HomeDiscoveryTab.tournaments => _tournaments(
      _ref.read(tournamentBrowseControllerProvider),
      search: query,
      limit: _searchLimit,
    ),
  };

  @override
  Future<List<DiscoverySuggestion>> featured(HomeDiscoveryTab tab) {
    final presets = _presets;
    return switch (tab) {
      HomeDiscoveryTab.sessions => _sessions(
        presets.sessionFilters(),
        _featuredLimit,
      ),
      HomeDiscoveryTab.venues => _venues(
        presets.venueFilter(),
        _featuredLimit,
      ),
      HomeDiscoveryTab.clubs => _clubs(
        ClubsState(
          city: presets.city,
          // The featured list is "Nhóm nổi bật" — pin the popular sort so the
          // preview matches what "Xem tất cả" applies, regardless of the
          // browse list's current (distance) sort.
          sortBy: HomeDiscoveryPresets.clubSort,
          latitude: _ref.read(clubsControllerProvider).latitude,
          longitude: _ref.read(clubsControllerProvider).longitude,
        ),
        search: '',
        limit: _featuredLimit,
      ),
      HomeDiscoveryTab.tournaments => _tournaments(
        TournamentBrowseState(
          city: presets.city,
          // Spelled out so the preview follows the preset, not a default
          // that happens to match it today.
          // ignore: avoid_redundant_argument_values
          statuses: HomeDiscoveryPresets.tournamentStatuses,
          // Same reason as statuses.
          // ignore: avoid_redundant_argument_values
          sort: HomeDiscoveryPresets.tournamentSort,
        ),
        search: '',
        limit: _featuredLimit,
      ),
    };
  }

  Future<List<DiscoverySuggestion>> _sessions(
    BrowseSessionFilters filters,
    int limit,
  ) async {
    final page = await _ref
        .read(sessionRepositoryProvider)
        .browseFiltered(filters, page: 1, limit: limit);
    return [for (final session in page.items) _fromSession(session)];
  }

  Future<List<DiscoverySuggestion>> _venues(
    VenueFilter filter,
    int limit,
  ) async {
    final page = await _ref
        .read(venueServiceProvider)
        .browse(filter, page: 1, limit: limit);
    return [for (final venue in page.venues) _fromVenue(venue)];
  }

  Future<List<DiscoverySuggestion>> _clubs(
    ClubsState state, {
    required String search,
    required int limit,
  }) async {
    // Clubs are re-sorted on the client per page, so the preview takes its
    // rows from a page of the default size the browse list also loads.
    final page = await _ref
        .read(socialServiceProvider)
        .browseClubs(
          page: 1,
          search: search,
          city: state.city,
          district: state.district,
          sortBy: state.sortBy,
          favoriteOnly: state.favoriteOnly,
          latitude: state.latitude,
          longitude: state.longitude,
        );
    return [
      for (final club in sortClubs(page.clubs, state.sortBy).take(limit))
        _fromClub(club),
    ];
  }

  Future<List<DiscoverySuggestion>> _tournaments(
    TournamentBrowseState state, {
    required String search,
    required int limit,
  }) async {
    final tournaments = await _ref
        .read(tournamentServiceProvider)
        .browse(
          search: search,
          city: state.city,
          statuses: state.statuses,
          sportTypes: state.sportTypes,
          favoriteOnly: state.favoriteOnly,
          sortBy: state.sort.sortBy,
          sortOrder: state.sort.sortOrder,
        );
    return [
      for (final tournament in tournaments.take(limit))
        _fromTournament(tournament),
    ];
  }

  DiscoverySuggestion _fromSession(Session session) => DiscoverySuggestion(
    tab: HomeDiscoveryTab.sessions,
    entityId: session.id,
    title: session.name,
    subtitle: session.venue?.name ?? session.location,
    imageUrl: session.coverPhoto,
    startsAt: session.displayStartTime,
    endsAt: session.plannedEndTime,
  );

  DiscoverySuggestion _fromVenue(Venue venue) => DiscoverySuggestion(
    tab: HomeDiscoveryTab.venues,
    entityId: venue.id,
    title: venue.name,
    subtitle: venue.addressLabel(showNewAddress: _showNewAddress),
    imageUrl: venue.logo ?? venue.coverPhoto,
  );

  DiscoverySuggestion _fromClub(ClubSummary club) => DiscoverySuggestion(
    tab: HomeDiscoveryTab.clubs,
    entityId: club.slug ?? club.id,
    title: club.name,
    subtitle: club.defaultVenue?.name ?? club.location,
    imageUrl: club.logo ?? club.image,
    memberCount: club.memberCount,
  );

  DiscoverySuggestion _fromTournament(TournamentSummary tournament) =>
      DiscoverySuggestion(
        tab: HomeDiscoveryTab.tournaments,
        entityId: tournament.slug ?? tournament.id,
        title: tournament.name,
        subtitle: tournament.displayLocation(showNewAddress: _showNewAddress),
        imageUrl: tournament.coverPhoto,
        startsAt: tournament.startDate,
        endsAt: tournament.endDate,
      );
}

final homeSearchSuggestionServiceProvider =
    Provider<HomeSearchSuggestionService>(
      ApiHomeSearchSuggestionService.new,
    );

/// The featured preview for a tab. Re-fetches when the preferred city
/// changes; the screen retries with `ref.invalidate`.
final homeSearchFeaturedProvider = FutureProvider.autoDispose
    .family<List<DiscoverySuggestion>, HomeDiscoveryTab>((ref, tab) {
      ref.watch(
        locationPreferencesControllerProvider.select(
          (preferences) => preferences.preferredCity,
        ),
      );
      return ref.watch(homeSearchSuggestionServiceProvider).featured(tab);
    });
