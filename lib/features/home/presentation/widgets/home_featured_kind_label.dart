import 'package:vmito_app/features/home/application/home_discovery_presets.dart';
import 'package:vmito_app/l10n/app_localizations.dart';

/// One title per preset, shared by the search screen section and the Home
/// results bar it opens, so "see all" lands under the heading it promised.
extension HomeFeaturedKindLabel on HomeFeaturedKind {
  String label(AppLocalizations l10n, {String? city}) => switch (this) {
    HomeFeaturedKind.sessionsWithSlots => l10n.homeSearchFeaturedSessions,
    HomeFeaturedKind.venuesNearby => l10n.homeSearchFeaturedVenuesNearby,
    HomeFeaturedKind.venuesInCity when city != null =>
      l10n.homeSearchFeaturedVenuesInCity(city),
    HomeFeaturedKind.venuesInCity => l10n.homeSearchFeaturedVenues,
    HomeFeaturedKind.clubsActive => l10n.homeSearchFeaturedClubs,
    HomeFeaturedKind.tournamentsUpcoming => l10n.homeSearchFeaturedTournaments,
  };
}
