// The provider's type is whatever `FutureProvider.family` returns; spelling it
// out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/shared/models/match.dart';

/// Finished matches in a session, for the repeat-pairing warning.
///
/// Only FINISHED rows count: a match still on court is the one being judged,
/// not part of its own history.
final matchHistoryProvider = FutureProvider.family<List<Match>, String>((
  ref,
  sessionId,
) async {
  final matches = await ref.watch(sessionRepositoryProvider).matches(sessionId);
  return [
    for (final match in matches)
      if (match.status == MatchStatus.finished) match,
  ];
});
