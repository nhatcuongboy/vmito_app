import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/venue/domain/venue.dart';

class VenueService {
  const VenueService(this._client);
  final ApiClient _client;

  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;

  Future<VenuePage> browse(
    VenueFilter filter, {
    required int page,
    int limit = 15,
  }) async {
    final sort = filter.sortBy;
    final response = await _client.get<dynamic>(
      ApiEndpoints.venueSearch,
      queryParameters: {
        'page': page,
        'limit': limit,
        'closureStatus': 'OPERATING',
        if (filter.keyword.trim().isNotEmpty) 'keyword': filter.keyword.trim(),
        if (filter.city?.isNotEmpty ?? false) 'city': filter.city,
        if (filter.district?.isNotEmpty ?? false) 'district': filter.district,
        if (filter.favoriteOnly) 'favoriteOnly': true,
        'sortBy': sort,
        'sortOrder': sort == 'name' ? 'asc' : 'desc',
        if (sort == 'distance' && filter.latitude != null)
          'lat': filter.latitude,
        if (sort == 'distance' && filter.longitude != null)
          'lng': filter.longitude,
      },
    );
    return VenuePage.fromJson(_payload(response.data));
  }

  Future<Venue> byId(String id) async {
    final response = await _client.get<dynamic>(ApiEndpoints.venue(id));
    return Venue.fromJson(_payload(response.data) as Map<String, dynamic>);
  }

  Future<List<VenuePriceBook>> priceBooks(String id) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.venuePriceBooks(id),
    );
    return (_payload(response.data) as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VenuePriceBook.fromJson)
        .toList(growable: false);
  }

  Future<void> createRequest({
    required String type,
    String? venueId,
    required Map<String, dynamic> payload,
  }) => _client.post<dynamic>(
    ApiEndpoints.venueRequests,
    data: {
      'type': type,
      'venueId': ?venueId,
      'payload': payload,
    },
  );

  Future<({String url, String? publicId})> uploadImage(String path) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: const {'category': 'OTHER'},
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(
          path,
          filename: File(path).uri.pathSegments.last,
        ),
      }),
    );
    final json = _payload(response.data) as Map<String, dynamic>;
    return (
      url: (json['url'] ?? json['secureUrl'] ?? '') as String,
      publicId: (json['publicId'] ?? json['cloudinaryPublicId']) as String?,
    );
  }
}

final venueServiceProvider = Provider<VenueService>(
  (ref) => VenueService(ref.watch(apiClientProvider)),
);
