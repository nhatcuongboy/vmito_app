/// Where a session happens, as the backend accepts it.
///
/// `CreateSessionDto` takes `locationType` alongside **either** `venueId`
/// **or** a `customLocation` object, never both. A pair of nullable fields
/// would let a caller send both or neither and only find out from a 400, so
/// the exclusivity is encoded in the type instead: there is no way to build a
/// [SessionLocationPayload] that is half of each.
sealed class SessionLocationPayload {
  const SessionLocationPayload();

  /// The fields to merge into the create/update body.
  Map<String, dynamic> toJson();
}

/// A venue that exists in Vmito. The canonical case.
final class VenueLocation extends SessionLocationPayload {
  const VenueLocation(this.venueId);

  final String venueId;

  @override
  Map<String, dynamic> toJson() => {
    'locationType': 'VENUE',
    'venueId': venueId,
  };
}

/// A place the host named themselves, because Vmito has no record of it.
///
/// Only [name] is required — the backend marks every other field optional, so
/// a host with no Places key still gets a usable session.
final class CustomLocation extends SessionLocationPayload {
  const CustomLocation({
    required this.name,
    this.address,
    this.placeId,
    this.lat,
    this.lng,
    this.district,
    this.city,
  });

  final String name;
  final String? address;

  /// Set only when the address came from a Places suggestion. Typed addresses
  /// carry no id, and inventing one would point at the wrong place.
  final String? placeId;
  final double? lat;
  final double? lng;
  final String? district;
  final String? city;

  @override
  Map<String, dynamic> toJson() => {
    'locationType': 'CUSTOM',
    'customLocation': {
      'name': name.trim(),
      if (address?.trim().isNotEmpty ?? false) 'address': address!.trim(),
      if (placeId?.isNotEmpty ?? false) 'placeId': placeId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (district?.trim().isNotEmpty ?? false) 'district': district!.trim(),
      if (city?.trim().isNotEmpty ?? false) 'city': city!.trim(),
    },
  };
}
