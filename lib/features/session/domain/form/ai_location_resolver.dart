/// What an AI extraction says about where a session happens, reduced to the
/// branches the form can act on.
///
/// Ported from `vmito-fe/src/components/session/session-form/aiLocationResolver.ts`.
/// The backend is the only place that matches a venue: [AiVenueLocation] means
/// it confirmed one, [AiCustomLocation] means it looked and did not find one.
/// There is deliberately no branch where the client guesses a venue itself.
sealed class AiLocationResolution {
  const AiLocationResolution();
}

final class AiVenueLocation extends AiLocationResolution {
  const AiVenueLocation(this.venueId);

  final String venueId;
}

final class AiCustomLocation extends AiLocationResolution {
  const AiCustomLocation({
    required this.name,
    this.address,
    this.district,
    this.city,
  });

  final String name;
  final String? address;
  final String? district;
  final String? city;
}

/// The post named no place at all. The form is left untouched rather than
/// blanked — an absent field must never clear what the host already typed.
final class AiNoLocation extends AiLocationResolution {
  const AiNoLocation();
}

String? _clean(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

/// Reduces the extraction's location fields to one resolution.
AiLocationResolution resolveAiLocation({
  String? venueId,
  String? location,
  String? venueName,
  String? venueAddress,
  String? venueDistrict,
  String? venueNewDistrict,
  String? venueCity,
  String? venueNewCity,
}) {
  final matched = _clean(venueId);
  if (matched != null) return AiVenueLocation(matched);

  // Name falls back through venue name -> display location -> address, so a
  // post that only yielded a free-form string still produces a usable custom
  // location instead of an empty required field.
  final name = _clean(venueName) ?? _clean(location) ?? _clean(venueAddress);
  if (name == null) return const AiNoLocation();

  final address = _clean(venueAddress);

  return AiCustomLocation(
    name: name,
    // Echoing the name back as the address just reads as duplicated text.
    address: address != null && address != name ? address : null,
    // The new administrative units supersede the old ones when the AI could
    // identify them.
    district: _clean(venueNewDistrict) ?? _clean(venueDistrict),
    city: _clean(venueNewCity) ?? _clean(venueCity),
  );
}
