import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';

/// Ports `vmito-fe/src/lib/api/favorite.service.ts`.
///
/// Every call needs a token — the backend reads the owner from the JWT, so
/// there is no signed-out variant to fall back to.
abstract interface class FavoriteRepository {
  Future<FavoriteSummary> summary(FavoriteType type, String targetId);

  Future<void> add(FavoriteType type, String targetId);

  Future<void> remove(FavoriteType type, String targetId);
}

class FavoriteRepositoryImpl implements FavoriteRepository {
  const FavoriteRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<FavoriteSummary> summary(FavoriteType type, String targetId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.favoriteSummary(type.wireValue, targetId),
    );
    return unwrap(response.data, FavoriteSummary.fromJson);
  }

  @override
  Future<void> add(FavoriteType type, String targetId) async {
    await _client.post<dynamic>(
      ApiEndpoints.favorites,
      data: {'type': type.wireValue, 'targetId': targetId},
    );
  }

  @override
  Future<void> remove(FavoriteType type, String targetId) async {
    await _client.delete<dynamic>(
      ApiEndpoints.favorite(type.wireValue, targetId),
    );
  }
}

final favoriteRepositoryProvider = Provider<FavoriteRepository>(
  (ref) => FavoriteRepositoryImpl(ref.watch(apiClientProvider)),
);
