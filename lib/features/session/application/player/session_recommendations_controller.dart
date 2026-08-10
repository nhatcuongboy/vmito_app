// The provider's type is whatever `FutureProvider.family` returns; spelling it
// out fights the library's generics and gains nothing.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/session/data/repositories/session_repository_impl.dart';
import 'package:vmito_app/features/session/domain/session.dart';

/// How many cards the detail screen's carousel shows. The web app asks for
/// the same page size.
const sessionRecommendationLimit = 6;

/// Sessions to suggest below a session's detail.
///
/// Signed out this still returns results — the backend falls back to a
/// generic ranking without a `userId`, which is what a browsing visitor
/// should see rather than an empty rail.
final sessionRecommendationsProvider = FutureProvider.family<
  List<Session>,
  String
>((ref, sessionId) async {
  final page = await ref
      .watch(sessionRepositoryProvider)
      .recommendations(
        sessionId,
        limit: sessionRecommendationLimit,
        userId: ref.watch(currentUserProvider)?.id,
      );
  // The current session can come back in its own recommendations when the
  // backend falls back to a generic ranking.
  return page.items.where((session) => session.id != sessionId).toList();
});
