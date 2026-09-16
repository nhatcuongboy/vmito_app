import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/roster/domain/host_recent_player.dart';
import 'package:vmito_app/features/roster/domain/player_profile.dart';
import 'package:vmito_app/features/roster/domain/player_profile_draft.dart';
import 'package:vmito_app/features/roster/domain/player_profile_stats.dart';

class RosterService {
  const RosterService(this._client);

  final ApiClient _client;

  Future<List<PlayerProfile>> getProfiles({
    String? clubId,
    String? search,
    String? status,
  }) async {
    final query = <String, dynamic>{
      if (clubId != null && clubId.isNotEmpty) 'clubId': clubId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final response = await _client.get<dynamic>(
      ApiEndpoints.playerProfiles,
      queryParameters: query,
    );
    return unwrapList(response.data, PlayerProfile.fromJson);
  }

  Future<PlayerProfile> getProfile(String id) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.playerProfile(id),
    );
    return unwrap(response.data, PlayerProfile.fromJson);
  }

  Future<PlayerProfileStats> getStats(String id) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.playerProfileStats(id),
    );
    return unwrap(response.data, PlayerProfileStats.fromJson);
  }

  Future<PlayerProfile> createProfile(CreatePlayerProfileDraft draft) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.playerProfiles,
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, PlayerProfile.fromJson);
  }

  Future<PlayerProfile> updateProfile(
    String id,
    UpdatePlayerProfileDraft draft,
  ) async {
    final response = await _client.patch<dynamic>(
      ApiEndpoints.playerProfile(id),
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    return unwrap(response.data, PlayerProfile.fromJson);
  }

  Future<void> deleteProfile(String id) async {
    await _client.delete<dynamic>(
      ApiEndpoints.playerProfile(id),
      options: apiOptions(skipGlobalError: true),
    );
  }

  Future<Map<String, dynamic>> promoteProfile(
    String id,
    PromoteProfileDraft draft,
  ) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.playerProfilePromote(id),
      data: draft.toJson(),
      options: apiOptions(skipGlobalError: true),
    );
    final body = response.data;
    final payload = body is Map<String, dynamic> && body.containsKey('data')
        ? body['data']
        : body;
    return payload is Map<String, dynamic>
        ? Map<String, dynamic>.from(payload)
        : <String, dynamic>{};
  }

  Future<List<HostRecentPlayer>> getHostRecentPlayers({
    String? clubId,
    String? search,
  }) async {
    final query = <String, dynamic>{
      if (clubId != null && clubId.isNotEmpty) 'clubId': clubId,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };
    final response = await _client.get<dynamic>(
      ApiEndpoints.hostRecentPlayers,
      queryParameters: query,
    );
    return unwrapList(response.data, HostRecentPlayer.fromJson);
  }
}

final rosterServiceProvider = Provider<RosterService>((ref) {
  return RosterService(ref.watch(apiClientProvider));
});
