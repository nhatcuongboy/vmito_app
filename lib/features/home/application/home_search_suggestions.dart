import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/location/location_preferences_controller.dart';
import 'package:vmito_app/features/home/domain/discovery_suggestion.dart';
import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/tournament/data/tournament_service.dart';
import 'package:vmito_app/features/venue/data/venue_service.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

// Kept as a boundary so widget tests can supply deterministic suggestions.
// ignore: one_member_abstracts
abstract interface class HomeSearchSuggestionService {
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
    String? city,
  });
}

class ApiHomeSearchSuggestionService implements HomeSearchSuggestionService {
  const ApiHomeSearchSuggestionService(this._ref);

  static const _limit = 5;
  final Ref _ref;

  @override
  Future<List<DiscoverySuggestion>> search({
    required HomeDiscoveryTab tab,
    required String query,
    String? city,
  }) => switch (tab) {
    HomeDiscoveryTab.sessions => _sessions(query),
    HomeDiscoveryTab.venues => _venues(query, city),
    HomeDiscoveryTab.clubs => _clubs(query, city),
    HomeDiscoveryTab.tournaments => _tournaments(query, city),
  };

  Future<List<DiscoverySuggestion>> _sessions(String query) async {
    final page = await _ref
        .read(sessionRepositoryProvider)
        .browsePublic(limit: _limit, search: query);
    return [
      for (final session in page.items)
        DiscoverySuggestion(
          tab: HomeDiscoveryTab.sessions,
          entityId: session.id,
          title: session.name,
          subtitle: session.venue?.name ?? session.location,
          imageUrl: session.coverPhoto,
        ),
    ];
  }

  Future<List<DiscoverySuggestion>> _venues(String query, String? city) async {
    final showNewAddress = _ref
        .read(locationPreferencesControllerProvider)
        .showNewAddress;
    final page = await _ref
        .read(venueServiceProvider)
        .browse(
          VenueFilter(keyword: query, city: city, sortBy: 'relevance'),
          page: 1,
          limit: _limit,
        );
    return [
      for (final venue in page.venues)
        DiscoverySuggestion(
          tab: HomeDiscoveryTab.venues,
          entityId: venue.id,
          title: venue.name,
          subtitle: venue.addressLabel(showNewAddress: showNewAddress),
          imageUrl: venue.logo ?? venue.coverPhoto,
        ),
    ];
  }

  Future<List<DiscoverySuggestion>> _clubs(String query, String? city) async {
    final page = await _ref
        .read(socialServiceProvider)
        .browseClubs(page: 1, limit: _limit, search: query, city: city);
    return [
      for (final club in page.clubs)
        DiscoverySuggestion(
          tab: HomeDiscoveryTab.clubs,
          entityId: club.slug ?? club.id,
          title: club.name,
          subtitle: club.defaultVenue?.name ?? club.location,
          imageUrl: club.logo ?? club.image,
        ),
    ];
  }

  Future<List<DiscoverySuggestion>> _tournaments(
    String query,
    String? city,
  ) async {
    final tournaments = await _ref
        .read(tournamentServiceProvider)
        .browse(search: query, city: city);
    final showNewAddress = _ref
        .read(locationPreferencesControllerProvider)
        .showNewAddress;
    return [
      for (final tournament in tournaments.take(_limit))
        DiscoverySuggestion(
          tab: HomeDiscoveryTab.tournaments,
          entityId: tournament.slug ?? tournament.id,
          title: tournament.name,
          subtitle: tournament.displayLocation(showNewAddress: showNewAddress),
          imageUrl: tournament.coverPhoto,
        ),
    ];
  }
}

final homeSearchSuggestionServiceProvider =
    Provider<HomeSearchSuggestionService>(
      ApiHomeSearchSuggestionService.new,
    );
