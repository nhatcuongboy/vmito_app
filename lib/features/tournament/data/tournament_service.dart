import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentService {
  const TournamentService(this._client);

  final ApiClient _client;

  Future<TournamentSummary> create(TournamentCreateRequest request) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.tournaments,
      data: request.toJson(),
    );
    return unwrap(response.data, TournamentSummary.fromJson);
  }

  Future<TournamentDetail> detail(String idOrSlug) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournament(idOrSlug),
    );
    return unwrap(response.data, TournamentDetail.fromJson);
  }

  Future<List<TournamentMatch>> matches(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentMatches(tournamentId),
    );
    return unwrapList(response.data, TournamentMatch.fromJson);
  }

  Future<List<TournamentSponsor>> sponsors(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentSponsors(tournamentId),
    );
    final sponsors = unwrapList(response.data, TournamentSponsor.fromJson);
    return sponsors..sort(
      (first, second) => first.displayOrder.compareTo(second.displayOrder),
    );
  }

  Future<List<TournamentStandingGroup>> standings(String categoryId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentStandings(categoryId),
    );
    return unwrapList(response.data, TournamentStandingGroup.fromJson);
  }

  Future<List<TournamentSummary>> browse({
    String search = '',
    String? city,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.tournaments,
      queryParameters: {
        'publishedOnly': true,
        'status': 'PREPARING',
        'sortBy': 'startDate',
        'sortOrder': 'asc',
        if (search.trim().isNotEmpty) 'keyword': search.trim(),
        if (city?.trim().isNotEmpty ?? false) 'city': city!.trim(),
      },
    );
    return unwrapList(
      response.data,
      TournamentSummary.fromJson,
    ).where((tournament) => tournament.isPublished).toList(growable: false);
  }
}

final tournamentServiceProvider = Provider<TournamentService>(
  (ref) => TournamentService(ref.watch(apiClientProvider)),
);
