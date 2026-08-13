import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/tournament_summary.dart';

class TournamentService {
  const TournamentService(this._client);

  final ApiClient _client;

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
