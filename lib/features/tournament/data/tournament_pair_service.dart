import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/tournament_pair_draft.dart';

/// Port of vmito-fe `lib/api/tournament-pair.service.ts`.
class TournamentPairService {
  const TournamentPairService(this._client);

  final ApiClient _client;

  /// Returns the new pair's id — the only field callers need to register it.
  Future<String> create(String tournamentId, TournamentPairDraft draft) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.tournamentPairs(tournamentId),
      data: draft.toJson(),
    );
    return unwrap(response.data, (json) => json['id'] as String);
  }

  Future<void> update(String id, TournamentPairDraft draft) async {
    await _client.put<dynamic>(
      ApiEndpoints.tournamentPair(id),
      data: draft.toJson(),
    );
  }
}

final tournamentPairServiceProvider = Provider<TournamentPairService>(
  (ref) => TournamentPairService(ref.watch(apiClientProvider)),
);
