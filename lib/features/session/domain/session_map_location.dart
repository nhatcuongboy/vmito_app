import 'package:vmito_app/features/session/domain/session.dart';

/// Sessions sharing a linked venue are rendered under one map marker.
/// A custom location belongs only to the session that created it, matching
/// the web implementation.
class SessionMapLocation {
  const SessionMapLocation({
    required this.key,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.sessions,
    this.address,
  });

  final String key;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final List<Session> sessions;
}

List<SessionMapLocation> groupSessionsByMapLocation(
  Iterable<Session> sessions,
) {
  final groups = <String, SessionMapLocation>{};

  for (final session in sessions) {
    final venue = session.venue;
    if (venue?.lat != null && venue?.lng != null) {
      final key = 'venue:${venue!.id}';
      final existing = groups[key];
      groups[key] = SessionMapLocation(
        key: key,
        name: venue.name?.trim().isNotEmpty ?? false
            ? venue.name!.trim()
            : session.location?.trim().isNotEmpty ?? false
            ? session.location!.trim()
            : session.name,
        address: venue.address,
        latitude: venue.lat!,
        longitude: venue.lng!,
        sessions: [...?existing?.sessions, session],
      );
      continue;
    }

    final latitude = session.customLocationLat;
    final longitude = session.customLocationLng;
    if (latitude == null || longitude == null) continue;
    final key = 'custom:${session.id}';
    groups[key] = SessionMapLocation(
      key: key,
      name: session.customLocationName?.trim().isNotEmpty ?? false
          ? session.customLocationName!.trim()
          : session.location?.trim().isNotEmpty ?? false
          ? session.location!.trim()
          : session.name,
      address: session.customLocationAddress,
      latitude: latitude,
      longitude: longitude,
      sessions: [session],
    );
  }

  return groups.values.toList(growable: false);
}
