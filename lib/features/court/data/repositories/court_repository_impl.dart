import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/court/domain/match_result_draft.dart';
import 'package:vmito_app/features/court/domain/player_position.dart';
import 'package:vmito_app/features/court/domain/repositories/court_repository.dart';
import 'package:vmito_app/features/court/domain/suggested_players.dart';
import 'package:vmito_app/shared/models/court.dart';
import 'package:vmito_app/shared/models/match.dart';
import 'package:vmito_app/shared/models/pre_selected_slot.dart';

/// Port of `vmito-fe/src/lib/api/court.service.ts`.
class CourtRepositoryImpl implements CourtRepository {
  const CourtRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Court> byId(String courtId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.court(courtId),
    );
    return unwrap(response.data, Court.fromJson);
  }

  @override
  Future<void> selectPlayers(
    String courtId,
    List<PlayerPosition> players,
  ) async {
    await _client.post<void>(
      ApiEndpoints.courtSelectPlayers(courtId),
      data: _positionedBody(players, listKey: 'players'),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> deselectPlayers(String courtId) async {
    await _client.post<void>(
      ApiEndpoints.courtDeselectPlayers(courtId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> startMatch(String courtId) async {
    await _client.post<void>(
      ApiEndpoints.courtStartMatch(courtId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> endMatch(String courtId, MatchResultDraft result) async {
    await _client.post<void>(
      ApiEndpoints.courtEndMatch(courtId),
      data: result.toRequestBody(),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<Match?> currentMatch(String courtId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.courtCurrentMatch(courtId),
    );
    // An idle court answers 200 with a null payload rather than 404.
    final body = response.data;
    if (body == null) return null;
    final payload = body['success'] == true ? body['data'] : body;
    if (payload is! Map<String, dynamic>) return null;
    return Match.fromJson(payload);
  }

  @override
  Future<void> preSelect(String courtId, List<PlayerPosition> players) async {
    await _client.post<void>(
      ApiEndpoints.courtPreSelect(courtId),
      // The pre-select DTO names the same list `playersWithPosition`.
      data: {'playersWithPosition': _positions(players)},
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<void> cancelPreSelect(String courtId) async {
    await _client.delete<void>(
      ApiEndpoints.courtPreSelect(courtId),
      options: apiOptions(skipGlobalError: true),
    );
  }

  @override
  Future<List<PreSelectedSlot>> preSelection(String courtId) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.courtPreSelect(courtId),
    );
    final body = response.data;
    if (body == null) return const [];
    final payload = body['success'] == true ? body['data'] : body;
    // The endpoint answers `{preSelectedPlayers: [...] }`, null when unset.
    final slots = payload is Map<String, dynamic>
        ? payload['preSelectedPlayers']
        : null;
    if (slots is! List) return const [];
    return slots
        .cast<Map<String, dynamic>>()
        .map(PreSelectedSlot.fromJson)
        .toList(growable: false);
  }

  @override
  Future<SuggestedPlayers> suggestedPlayers(
    String courtId, {
    int? topCount,
    bool useAi = false,
    String? language,
    MatchType? matchType,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.suggestedPlayers(courtId),
      queryParameters: {
        if (topCount != null) 'topCount': '$topCount',
        // The backend compares against the literal string 'true'.
        'useAi': useAi ? 'true' : 'false',
        'language': ?language,
        if (matchType != null) 'matchType': matchType.name.toUpperCase(),
      },
      // A suggestion is a fresh decision every time; sharing an in-flight
      // response across two opens of the sheet would show stale pairings.
      dedup: false,
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, SuggestedPlayers.fromJson);
  }

  /// `SelectPlayersDto` accepts `playerIds` or `players`; the web sends both,
  /// so we do too. `playerIds` follows slot order to stay consistent with the
  /// positions in [listKey].
  Map<String, dynamic> _positionedBody(
    List<PlayerPosition> players, {
    required String listKey,
  }) {
    final sorted = [...players]
      ..sort((a, b) => a.position.compareTo(b.position));
    return {
      'playerIds': sorted.map((p) => p.playerId).toList(growable: false),
      listKey: _positions(sorted),
    };
  }

  List<Map<String, dynamic>> _positions(List<PlayerPosition> players) => [
    for (final player in players)
      {'playerId': player.playerId, 'position': player.position},
  ];
}

final courtRepositoryProvider = Provider<CourtRepository>(
  (ref) => CourtRepositoryImpl(ref.watch(apiClientProvider)),
);
