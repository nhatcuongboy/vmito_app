// The provider's type is whatever `FutureProvider.family` returns; spelling it
// out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/social/data/social_service.dart';

/// What the host sheet shows besides the session's own host fields.
class HostDetailStats {
  const HostDetailStats({
    required this.averageRating,
    required this.totalRatings,
    required this.hostedSessions,
    required this.openSessions,
  });

  final double averageRating;
  final int totalRatings;
  final int hostedSessions;
  final int openSessions;

  bool get hasRating => totalRatings > 0;

  /// The web app's threshold for the "trusted host" badge.
  bool get isTrusted => hasRating && averageRating >= 4.5;
}

/// Host reputation and session counts, as the web app's `AppHostDetail` loads
/// them.
///
/// Each call falls back to zero on its own rather than failing the set: a host
/// with no ratings yet returns 404 from `/ratings`, and that must not blank out
/// the session counters.
final hostDetailStatsProvider = FutureProvider.family<HostDetailStats, String>((
  ref,
  hostId,
) async {
  final social = ref.watch(socialServiceProvider);
  final sessions = ref.watch(sessionRepositoryProvider);

  final (rating, hosted, open) = await (
    _orNull(social.ratingStats(hostId)),
    _orNull(sessions.publicSessionCountByHost(hostId)),
    _orNull(sessions.openSessionCountByHost(hostId)),
  ).wait;

  return HostDetailStats(
    averageRating: rating?.average ?? 0,
    totalRatings: rating?.total ?? 0,
    hostedSessions: hosted ?? 0,
    openSessions: open ?? 0,
  );
});

Future<T?> _orNull<T>(Future<T> future) =>
    future.then<T?>((value) => value, onError: (_) => null);
