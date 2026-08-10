// Provider declarations intentionally use inferred types; spelling out the
// nested family generics makes them harder to read and easier to get wrong.
// ignore_for_file: specify_nonobvious_property_types

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/auth/application/auth_controller.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';

/// Identifies one favoritable thing.
///
/// A record because Riverpod families take a single argument, and two
/// positional strings at the call site would be easy to swap.
typedef FavoriteTarget = ({FavoriteType type, String id});

/// Owns the heart state for one target.
///
/// The toggle is optimistic: a heart that waits for a round-trip feels
/// broken, and the failure path here is a re-read rather than a lost write.
class FavoriteController extends AsyncNotifier<FavoriteSummary> {
  FavoriteController(this.target);

  final FavoriteTarget target;

  @override
  Future<FavoriteSummary> build() async {
    // The endpoint is authenticated. Signed out there is nothing to read, so
    // report the empty summary rather than let a guaranteed 401 surface as an
    // error state on the hero.
    if (!ref.watch(isSignedInProvider)) return const FavoriteSummary();
    return ref
        .watch(favoriteRepositoryProvider)
        .summary(target.type, target.id);
  }

  /// Flips the heart. Returns false when nobody is signed in, so the caller
  /// can prompt for sign-in instead of silently doing nothing.
  Future<bool> toggle() async {
    if (!ref.read(isSignedInProvider)) return false;

    final current = state.value;
    if (current == null) return true;

    final next = current.copyWith(
      isFavorite: !current.isFavorite,
      favoriteCount: current.isFavorite
          // Guard against a stale zero: a count that goes negative looks like
          // a bug for the rest of the session.
          ? (current.favoriteCount - 1).clamp(0, current.favoriteCount)
          : current.favoriteCount + 1,
    );
    state = AsyncData(next);

    final repository = ref.read(favoriteRepositoryProvider);
    try {
      if (next.isFavorite) {
        await repository.add(target.type, target.id);
      } else {
        await repository.remove(target.type, target.id);
      }
    } on Object {
      // Re-read rather than restore `current`: the server is the authority,
      // and another device may have changed it meanwhile.
      ref.invalidateSelf();
      rethrow;
    }
    return true;
  }
}

final favoriteControllerProvider =
    AsyncNotifierProvider.family<
      FavoriteController,
      FavoriteSummary,
      FavoriteTarget
    >(FavoriteController.new);
