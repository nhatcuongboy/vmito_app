import 'package:vmito_app/features/home/domain/home_discovery_tab.dart';

/// One row in the search screen, for any discovery entity.
///
/// Dates and counts stay raw so the row can format them for the reader's
/// locale; the application layer has no `BuildContext`.
class DiscoverySuggestion {
  const DiscoverySuggestion({
    required this.tab,
    required this.entityId,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.startsAt,
    this.endsAt,
    this.memberCount,
  });

  final HomeDiscoveryTab tab;
  final String entityId;
  final String title;
  final String? subtitle;
  final String? imageUrl;

  /// Session start time, or tournament start date.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Clubs only.
  final int? memberCount;
}
