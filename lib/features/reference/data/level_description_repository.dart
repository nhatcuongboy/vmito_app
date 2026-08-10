import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/reference/domain/level_description.dart';

/// Ports `vmito-fe/src/lib/api/level-description.service.ts`.
///
/// No domain interface: one read-only call, and screens depend on
/// [levelDescriptionsProvider] rather than on this class, so there is nothing
/// for an abstraction to decouple.
class LevelDescriptionRepository {
  const LevelDescriptionRepository(this._client);

  final ApiClient _client;

  /// Public endpoint — a signed-out player can still read what `TBY` means.
  Future<List<LevelDescription>> findAll() async {
    final response = await _client.get<dynamic>(ApiEndpoints.levelDescriptions);
    return unwrapList(response.data, LevelDescription.fromJson);
  }
}

final levelDescriptionRepositoryProvider = Provider<LevelDescriptionRepository>(
  (ref) => LevelDescriptionRepository(ref.watch(apiClientProvider)),
);

/// Cached for the app's lifetime: the table changes about once a year, and
/// re-fetching it every time the sheet opens is a visible spinner for nothing.
final levelDescriptionsProvider = FutureProvider<List<LevelDescription>>(
  (ref) => ref.watch(levelDescriptionRepositoryProvider).findAll(),
);
