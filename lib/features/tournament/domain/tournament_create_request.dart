enum TournamentSportType { badminton, pickleball }

class TournamentLocationDraft {
  const TournamentLocationDraft({
    required this.name,
    this.placeId,
    this.address,
    this.latitude,
    this.longitude,
    this.district,
    this.city,
  });

  final String name;
  final String? placeId;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? district;
  final String? city;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    if (placeId?.trim().isNotEmpty ?? false) 'placeId': placeId!.trim(),
    if (address?.trim().isNotEmpty ?? false) 'address': address!.trim(),
    if (latitude != null) 'lat': latitude,
    if (longitude != null) 'lng': longitude,
    if (district?.trim().isNotEmpty ?? false) 'district': district!.trim(),
    if (city?.trim().isNotEmpty ?? false) 'city': city!.trim(),
  };
}

class TournamentCreateRequest {
  const TournamentCreateRequest({
    required this.name,
    required this.sportType,
    required this.startDate,
    required this.endDate,
    this.location,
  });

  final String name;
  final TournamentSportType sportType;
  final DateTime startDate;
  final DateTime endDate;
  final TournamentLocationDraft? location;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'sportType': switch (sportType) {
      TournamentSportType.badminton => 'BADMINTON',
      TournamentSportType.pickleball => 'PICKLEBALL',
    },
    // Match the web form: a calendar day is sent as midnight UTC, rather
    // than converting local midnight and accidentally shifting the date.
    'startDate': _utcDate(startDate).toIso8601String(),
    'endDate': _utcDate(endDate).toIso8601String(),
    if (location != null) 'location': location!.toJson(),
  };

  static DateTime _utcDate(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);
}
