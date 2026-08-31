import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/tournament_create_request.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_schedule.dart';
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

  Future<List<TournamentCourt>> courts(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentCourts(tournamentId),
    );
    return unwrapList(response.data, TournamentCourt.fromJson);
  }

  Future<List<TournamentCategoryGroup>> categoryGroups(
    String categoryId,
  ) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentCategoryGroups(categoryId),
    );
    return unwrapList(response.data, TournamentCategoryGroup.fromJson);
  }

  Future<List<TournamentUmpire>> umpires(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentUmpires(tournamentId),
    );
    return unwrapList(response.data, TournamentUmpire.fromJson);
  }

  Future<List<TournamentMatch>> ownAssignments(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.categoryMatchAssignments,
      queryParameters: {'tournamentId': tournamentId},
    );
    return unwrapList(response.data, TournamentMatch.fromJson);
  }

  Future<void> updateMatchCode(String matchId, String matchCode) async {
    await _client.put<dynamic>(
      ApiEndpoints.categoryMatch(matchId),
      data: {'matchCode': matchCode},
    );
  }

  Future<void> updateMatchSchedule(TournamentScheduleUpdateDraft draft) async {
    await _client.put<dynamic>(
      ApiEndpoints.categoryMatchBulkSchedule,
      data: {
        'updates': [
          {
            'matchId': draft.matchId,
            'courtId': draft.courtId,
            'startTime': draft.startTime?.toUtc().toIso8601String(),
            'endTime': draft.endTime?.toUtc().toIso8601String(),
          },
        ],
      },
    );
  }

  Future<TournamentMatch> assignReferee(
    String matchId,
    String refereeId,
  ) async {
    final response = await _client.patch<dynamic>(
      ApiEndpoints.categoryMatchReferee(matchId),
      data: {'refereeId': refereeId},
    );
    return unwrap(response.data, TournamentMatch.fromJson);
  }

  Future<TournamentMatch> unassignReferee(String matchId) async {
    final response = await _client.delete<dynamic>(
      ApiEndpoints.categoryMatchReferee(matchId),
    );
    return unwrap(response.data, TournamentMatch.fromJson);
  }

  Future<TournamentMatch> saveResult(
    String matchId,
    TournamentResultDraft draft,
  ) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.categoryMatchResult(matchId),
      data: draft.toJson(),
    );
    return unwrap(response.data, TournamentMatch.fromJson);
  }

  Future<TournamentMatch> resetResult(String matchId) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.categoryMatchReset(matchId),
    );
    return unwrap(response.data, TournamentMatch.fromJson);
  }

  Future<void> deleteMatch(String matchId) async {
    await _client.delete<dynamic>(ApiEndpoints.categoryMatch(matchId));
  }

  Future<void> completeGroupStage(String categoryId) async {
    await _client.post<dynamic>(
      ApiEndpoints.tournamentCompleteGroupStage(categoryId),
    );
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

  Future<void> calculateStandings(String categoryId, String groupId) async {
    await _client.post<dynamic>(
      ApiEndpoints.calculateTournamentStandings(categoryId, groupId),
    );
  }

  Future<List<TournamentSummary>> browse({
    String search = '',
    String? city,
    Set<TournamentStatus> statuses = const {TournamentStatus.preparing},
    Set<String> sportTypes = const {},
    bool favoriteOnly = false,
    String sortBy = 'startDate',
    String sortOrder = 'asc',
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.tournaments,
      queryParameters: {
        'publishedOnly': true,
        if (statuses.isNotEmpty)
          'status': statuses.map((status) => status.wireValue).join(','),
        if (sportTypes.isNotEmpty) 'sportType': sportTypes.join(','),
        if (favoriteOnly) 'favoriteOnly': true,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
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
