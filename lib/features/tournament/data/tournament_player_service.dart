import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

class TournamentPlayerService {
  const TournamentPlayerService(this._client);
  final ApiClient _client;

  Future<List<TournamentPlayer>> list(String tournamentId) async => unwrapList(
    (await _client.get<dynamic>(
      ApiEndpoints.tournamentPlayers(tournamentId),
      dedup: false,
    )).data,
    TournamentPlayer.fromJson,
  );

  Future<TournamentPlayer> save(
    String tournamentId,
    PlayerDraft draft, {
    String? id,
  }) async {
    final response = id == null
        ? await _client.post<dynamic>(
            ApiEndpoints.tournamentPlayers(tournamentId),
            data: draft.toJson(),
          )
        : await _client.put<dynamic>(
            ApiEndpoints.tournamentPlayer(id),
            data: draft.toJson(update: true),
          );
    return unwrap(response.data, TournamentPlayer.fromJson);
  }

  /// Name-only update. `save(..., id:)` sends every field and would clear the
  /// player's contact details, which the Teams panel never shows.
  Future<void> rename(String id, String name) async {
    await _client.put<dynamic>(
      ApiEndpoints.tournamentPlayer(id),
      data: {'name': name.trim()},
    );
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>(ApiEndpoints.tournamentPlayer(id));
  }

  Future<List<TournamentMatch>> matches(String id) async => unwrapList(
    (await _client.get<dynamic>(
      ApiEndpoints.tournamentPlayerMatches(id),
      dedup: false,
    )).data,
    TournamentMatch.fromJson,
  );

  Future<List<TournamentPlayer>> bulkCreate(
    String tournamentId,
    List<PlayerImportRow> rows,
  ) async {
    if (rows.isEmpty || rows.any((row) => row.errors.isNotEmpty)) {
      throw ArgumentError('Import must contain only valid rows');
    }
    final response = await _client.post<dynamic>(
      ApiEndpoints.tournamentPlayersBulk(tournamentId),
      data: {'rows': rows.map((row) => row.toJson()).toList()},
    );
    return unwrap(
      response.data,
      (json) => (json['players'] as List)
          .map(
            (item) => TournamentPlayer.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

final tournamentPlayerServiceProvider = Provider<TournamentPlayerService>(
  (ref) => TournamentPlayerService(ref.watch(apiClientProvider)),
);
