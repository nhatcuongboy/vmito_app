import 'package:vmito_app/core/location/address_display.dart';

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

  String get wireValue => switch (this) {
    TournamentStatus.preparing => 'PREPARING',
    TournamentStatus.inProgress => 'IN_PROGRESS',
    TournamentStatus.finished => 'FINISHED',
    TournamentStatus.cancelled => 'CANCELLED',
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
    this.isFavorite = false,
    this.hostId,
    this.categoryCount = 0,
    this.createdAt,
    this.slug,
    this.coverPhoto,
    this.location,
    this.venueName,
    this.venueAddress,
    this.venueDistrict,
    this.venueCity,
    this.venueNewAddress,
    this.venueNewDistrict,
    this.venueNewCity,
    this.venueLatitude,
    this.venueLongitude,
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
      isFavorite: json['isFavorite'] as bool? ?? false,
      hostId: json['hostId'] as String?,
      categoryCount: switch (json['_count']) {
        {'categories': final num count} => count.toInt(),
        _ => 0,
      },
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      coverPhoto: json['coverPhoto'] as String? ?? _venueCoverPhoto(venue),
      location: _venueLocation(venue),
      venueName: venue?['name'] as String?,
      venueAddress: venue?['address'] as String?,
      venueDistrict: venue?['district'] as String?,
      venueCity: venue?['city'] as String?,
      venueNewAddress: venue?['newAddress'] as String?,
      venueNewDistrict: venue?['newDistrict'] as String?,
      venueNewCity: venue?['newCity'] as String?,
      venueLatitude: (venue?['lat'] as num?)?.toDouble(),
      venueLongitude: (venue?['lng'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String? slug;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final TournamentStatus status;
  final bool isPublished;
  final bool isFavorite;
  final String? hostId;
  final int categoryCount;
  final DateTime? createdAt;
  final String? coverPhoto;
  final String? location;
  final String? venueName;
  final String? venueAddress;
  final String? venueDistrict;
  final String? venueCity;
  final String? venueNewAddress;
  final String? venueNewDistrict;
  final String? venueNewCity;
  final double? venueLatitude;
  final double? venueLongitude;

  bool get hasVenueCoordinates =>
      venueLatitude != null && venueLongitude != null;

  /// Still IN_PROGRESS after its last day, judged by the calendar in Vietnam.
  ///
  /// Mirrors web `isTournamentOverdue`: dates are stored as UTC midnight, so
  /// the UTC date part of [endDate] is the tournament's calendar day.
  bool isOverdue({DateTime? now}) {
    if (status != TournamentStatus.inProgress) return false;
    final end = endDate.toUtc();
    final vietnamNow = (now ?? DateTime.now()).toUtc().add(
      const Duration(hours: 7),
    );
    final endDay = DateTime.utc(end.year, end.month, end.day);
    final today = DateTime.utc(
      vietnamNow.year,
      vietnamNow.month,
      vietnamNow.day,
    );
    return endDay.isBefore(today);
  }

  String? displayLocation({required bool showNewAddress}) {
    final address = resolveAppAddress(
      showNewAddress: showNewAddress,
      address: venueAddress,
      district: venueDistrict,
      city: venueCity,
      newAddress: venueNewAddress,
    );
    final name = venueName?.trim();
    if (name != null && name.isNotEmpty) {
      final area = resolveCompactAddressArea(
        showNewAddress: showNewAddress,
        district: venueDistrict,
        city: venueCity,
        newDistrict: venueNewDistrict,
        newCity: venueNewCity,
      );
      if (area != null && area.isNotEmpty) return '$name · $area';
      return name;
    }
    return address.isEmpty ? location : address.text;
  }

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
