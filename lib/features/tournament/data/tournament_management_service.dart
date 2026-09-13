import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/tournament/domain/tournament_detail.dart';
import 'package:vmito_app/features/tournament/domain/tournament_management.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

class TournamentManagementService {
  const TournamentManagementService(this._client);

  final ApiClient _client;

  Future<TournamentMyAccess> access(String idOrSlug) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentMyAccess(idOrSlug),
      dedup: false,
    );
    return unwrap(response.data, TournamentMyAccess.fromJson);
  }

  Future<TournamentDetail> updateTournament(
    String id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _client.put<dynamic>(
      ApiEndpoints.tournament(id),
      data: changes,
    );
    return unwrap(response.data, TournamentDetail.fromJson);
  }

  Future<void> deleteTournament(String id) async {
    await _client.delete<dynamic>(ApiEndpoints.tournament(id));
  }

  Future<TournamentDetail> duplicateTournament(
    String id,
    DuplicateTournamentDraft draft,
  ) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.duplicateTournament(id),
      data: draft.toJson(),
    );
    return unwrap(response.data, TournamentDetail.fromJson);
  }

  Future<List<TournamentManager>> managers(String tournamentId) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.tournamentManagers(tournamentId),
      dedup: false,
    );
    return unwrapList(response.data, TournamentManager.fromJson);
  }

  Future<TournamentManager> addManager(
    String tournamentId,
    String userId,
    Set<TournamentPermission> permissions,
  ) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.tournamentManagers(tournamentId),
      data: {
        'userId': userId,
        'permissions': permissions.map((item) => item.wireValue).toList(),
      },
    );
    return unwrap(response.data, TournamentManager.fromJson);
  }

  Future<TournamentManager> updateManager(
    String tournamentId,
    String userId,
    Set<TournamentPermission> permissions,
  ) async {
    final response = await _client.patch<dynamic>(
      ApiEndpoints.tournamentManager(tournamentId, userId),
      data: {
        'permissions': permissions.map((item) => item.wireValue).toList(),
      },
    );
    return unwrap(response.data, TournamentManager.fromJson);
  }

  Future<void> removeManager(String tournamentId, String userId) async {
    await _client.delete<dynamic>(
      ApiEndpoints.tournamentManager(tournamentId, userId),
    );
  }

  Future<List<TournamentUserOption>> searchUsers(String query) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.users,
      queryParameters: {'search': query.trim()},
      dedup: false,
    );
    var payload = _payload(response.data);
    if (payload is Map<String, dynamic>) payload = payload['data'];
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(TournamentUserOption.fromJson)
        .toList(growable: false);
  }

  Future<List<TournamentImageAsset>> images({
    String? category = 'SESSION_COVER',
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {
        'category': ?category,
        'page': 1,
        'limit': 100,
      },
      dedup: false,
    );
    final payload = _payload(response.data);
    final raw = payload is Map<String, dynamic> ? payload['data'] : payload;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(TournamentImageAsset.fromJson)
        .where((image) => image.url.isNotEmpty && image.publicId.isNotEmpty)
        .toList(growable: false);
  }

  Future<List<Venue>> searchVenues(String query) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.venueSearch,
      queryParameters: {
        'page': 1,
        'limit': 100,
        'closureStatus': 'OPERATING',
        if (query.trim().isNotEmpty) 'keyword': query.trim(),
        if (query.trim().isNotEmpty) 'sortBy': 'relevance',
      },
      dedup: false,
    );
    final payload = _payload(response.data);
    final raw = payload is Map<String, dynamic> ? payload['data'] : payload;
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(Venue.fromJson)
        .toList(growable: false);
  }

  Future<({String url, String publicId})> uploadImage({
    required Uint8List bytes,
    required String filename,
    required String category,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 1920,
      quality: 82,
    );
    final response = await _client.post<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {'category': category},
      data: FormData.fromMap({
        'file': MultipartFile.fromBytes(compressed, filename: filename),
      }),
    );
    final json = (_payload(response.data) as Map).cast<String, dynamic>();
    final url = (json['url'] ?? json['secureUrl'] ?? '') as String;
    final publicId =
        (json['publicId'] ?? json['cloudinaryPublicId'] ?? '') as String;
    if (url.isEmpty || publicId.isEmpty) {
      throw StateError('Image upload returned no asset identifier');
    }
    return (url: url, publicId: publicId);
  }

  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;
}

final tournamentManagementServiceProvider =
    Provider<TournamentManagementService>(
      (ref) => TournamentManagementService(ref.watch(apiClientProvider)),
    );
