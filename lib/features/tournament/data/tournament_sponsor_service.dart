import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/form/tournament_resource_forms.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';

class TournamentSponsorService {
  const TournamentSponsorService(this._client);
  final ApiClient _client;

  Future<List<TournamentSponsor>> list(String tournamentId) async => unwrapList(
    (await _client.get<dynamic>(
      ApiEndpoints.tournamentSponsors(tournamentId),
      dedup: false,
    )).data,
    TournamentSponsor.fromJson,
  );

  Future<TournamentSponsor> save(
    String tournamentId,
    SponsorDraft draft, {
    String? id,
  }) async {
    final response = id == null
        ? await _client.post<dynamic>(
            ApiEndpoints.tournamentSponsors(tournamentId),
            data: draft.toJson(),
          )
        : await _client.put<dynamic>(
            ApiEndpoints.tournamentSponsor(id),
            data: draft.toJson(update: true),
          );
    return unwrap(response.data, TournamentSponsor.fromJson);
  }

  Future<void> delete(String id) async {
    await _client.delete<dynamic>(ApiEndpoints.tournamentSponsor(id));
  }
}

final tournamentSponsorServiceProvider = Provider<TournamentSponsorService>(
  (ref) => TournamentSponsorService(ref.watch(apiClientProvider)),
);
