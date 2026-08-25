import 'package:vmito_app/features/session/domain/session.dart';

/// A session row returned by `/sessions/:id/recommendations`.
///
/// The endpoint enriches ordinary session JSON with ranking and capacity
/// fields. Keep that transport-only data here instead of broadening [Session]
/// for every list endpoint.
class SessionRecommendation {
  const SessionRecommendation({
    required this.session,
    this.availableSlots,
    this.maxSlots,
  });

  factory SessionRecommendation.fromJson(Map<String, dynamic> json) {
    // The recommendations projection deliberately omits `status`: it only
    // ever queries PREPARING rows, whereas the shared Session JSON contract
    // requires a status. Normalise that narrow API difference at the boundary.
    final sessionJson = Map<String, dynamic>.from(json)
      ..putIfAbsent('status', () => 'PREPARING');
    return SessionRecommendation(
      session: Session.fromJson(sessionJson),
      availableSlots: _int(json['availableSlots']),
      maxSlots: _int(json['maxSlots']),
    );
  }

  final Session session;
  final int? availableSlots;
  final int? maxSlots;

  /// Uses the recommendation-specific value first; older API responses still
  /// render correctly from the ordinary session capacity fields.
  int? get displayAvailableSlots => availableSlots ?? session.availableSlots;

  int? get displayMaxSlots =>
      maxSlots ?? (session.capacity > 0 ? session.capacity : null);
}

/// First-page recommendation response including the backend's fallback flag.
class SessionRecommendationsPage {
  const SessionRecommendationsPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.isFallback,
  });

  final List<SessionRecommendation> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final bool isFallback;

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty;
}

int? _int(Object? value) => (value as num?)?.toInt();
