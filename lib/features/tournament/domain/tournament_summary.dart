enum TournamentStatus {
  preparing,
  inProgress,
  finished,
  cancelled;

  static TournamentStatus fromWire(String? value) => switch (value) {
    'IN_PROGRESS' => TournamentStatus.inProgress,
    'FINISHED' => TournamentStatus.finished,
    'CANCELLED' => TournamentStatus.cancelled,
    _ => TournamentStatus.preparing,
  };
}

/// The browse-list subset returned by `GET /tournaments`.
class TournamentSummary {
  const TournamentSummary({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.isPublished,
    this.slug,
    this.coverPhoto,
    this.location,
  });

  factory TournamentSummary.fromJson(Map<String, dynamic> json) {
    final venue = _displayVenue(json);
    return TournamentSummary(
      id: json['id'] as String,
      slug: json['slug'] as String?,
      name: json['name'] as String? ?? '',
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: TournamentStatus.fromWire(json['status'] as String?),
      isPublished: json['isPublished'] as bool? ?? false,
      coverPhoto: json['coverPhoto'] as String? ?? _venueCoverPhoto(venue),
      location: _venueLocation(venue),
    );
  }

  final String id;
  final String? slug;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final TournamentStatus status;
  final bool isPublished;
  final String? coverPhoto;
  final String? location;

  static Map<String, dynamic>? _displayVenue(Map<String, dynamic> json) {
    if (json['venue'] case final Map<String, dynamic> venue) return venue;

    final links = json['tournamentVenues'];
    if (links is! List) return null;
    final maps = links.whereType<Map<String, dynamic>>().toList();
    if (maps.isEmpty) return null;
    final primary = maps.where((item) => item['isPrimary'] == true).firstOrNull;
    final selected = primary ?? maps.first;
    return selected['venue'] is Map<String, dynamic>
        ? selected['venue'] as Map<String, dynamic>
        : selected;
  }

  static String? _venueCoverPhoto(Map<String, dynamic>? venue) {
    if (venue == null) return null;
    if (venue['coverPhoto'] case final String cover when cover.isNotEmpty) {
      return cover;
    }
    if (venue['images'] case final List<dynamic> images) {
      return images.whereType<String>().firstOrNull;
    }
    return null;
  }

  static String? _venueLocation(Map<String, dynamic>? venue) {
    if (venue == null) return null;
    final name = venue['name'] as String?;
    final city = venue['newCity'] as String? ?? venue['city'] as String?;
    final district =
        venue['newDistrict'] as String? ?? venue['district'] as String?;
    final parts = [
      name,
      city ?? district,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(' · ');
    return venue['address'] as String?;
  }
}
