import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_category_form.dart';
import 'package:vmito_app/features/tournament/domain/tournament_pair_draft.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_domain/vmito_domain.dart' as scoring;

/// Port of vmito-fe `lib/api/category.service.ts`.
class CategoryService {
  const CategoryService(this._client);

  final ApiClient _client;

  Future<List<TournamentCategory>> list(String tournamentId) async =>
      unwrapList(
        (await _client.get<dynamic>(
          ApiEndpoints.tournamentCategories(tournamentId),
          dedup: false,
        )).data,
        TournamentCategory.fromJson,
      );

  Future<TournamentCategory> create(
    String tournamentId,
    CategoryDraft draft, {
    required scoring.SportType sport,
  }) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.tournamentCategories(tournamentId),
      data: draft.toJson(create: true, sport: sport),
    );
    return unwrap(response.data, TournamentCategory.fromJson);
  }

  /// Also used for format and scoring changes — the backend has no dedicated
  /// endpoint for those.
  Future<TournamentCategory> update(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _client.put<dynamic>(
      ApiEndpoints.category(id),
      data: changes,
    );
    return unwrap(response.data, TournamentCategory.fromJson);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>(ApiEndpoints.category(id));
  }

  /// Exactly one of [playerId] / [pairId]; the backend rejects both or neither.
  Future<void> createRegistration(
    String categoryId, {
    String? playerId,
    String? pairId,
  }) async {
    assert((playerId == null) != (pairId == null), 'Pass exactly one id');
    await _client.post<dynamic>(
      ApiEndpoints.categoryRegistrations(categoryId),
      data: {'tournamentPlayerId': ?playerId, 'tournamentPairId': ?pairId},
    );
  }

  /// [names] creates new players (individual) or empty pairs (team);
  /// [playerIds] registers existing roster players (individual only).
  /// Already-registered players are skipped server-side.
  Future<void> bulkRegistrations(
    String categoryId, {
    List<String>? names,
    List<String>? playerIds,
  }) async {
    await _client.post<dynamic>(
      ApiEndpoints.categoryRegistrationsBulk(categoryId),
      data: {'names': ?names, 'tournamentPlayerIds': ?playerIds},
    );
  }

  Future<void> deleteRegistration(
    String categoryId,
    String registrationId,
  ) async {
    await _client.delete<dynamic>(
      ApiEndpoints.categoryRegistration(categoryId, registrationId),
    );
  }

  Future<void> convertToPair(
    String categoryId,
    String registrationId,
    TournamentPairDraft draft,
  ) async {
    await _client.put<dynamic>(
      ApiEndpoints.categoryRegistrationConvertToPair(
        categoryId,
        registrationId,
      ),
      data: draft.toJson(),
    );
  }
}

final categoryServiceProvider = Provider<CategoryService>(
  (ref) => CategoryService(ref.watch(apiClientProvider)),
);
