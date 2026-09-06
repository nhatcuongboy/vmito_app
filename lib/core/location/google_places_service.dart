import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_options.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/core/utils/logger.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
}

class PlaceDetails {
  const PlaceDetails({
    required this.placeId,
    required this.address,
    this.latitude,
    this.longitude,
    this.district,
    this.city,
  });

  final String placeId;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? district;
  final String? city;
}

/// Address autocomplete via Vmito's backend proxy.
///
/// The proxy owns the Google Places credential so the mobile binary never
/// contains a third-party secret.
class GooglePlacesService {
  const GooglePlacesService(this._client);

  final ApiClient _client;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String language,
  }) async {
    if (input.trim().length < 2) return const [];

    try {
      final response = await _client.post<Map<String, dynamic>>(
        ApiEndpoints.placesAutocomplete,
        data: {'input': input.trim(), 'language': language},
        options: apiOptions(skipGlobalError: true),
      );
      return unwrapList(
        response.data,
        _suggestionFromJson,
      ).where((item) => item.placeId.isNotEmpty).toList(growable: false);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GooglePlacesService.autocomplete failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<PlaceDetails> details({
    required String placeId,
    required String language,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        ApiEndpoints.placesDetails,
        queryParameters: {'placeId': placeId, 'language': language},
        options: apiOptions(skipGlobalError: true),
      );
      return unwrap(response.data, _detailsFromJson);
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GooglePlacesService.details failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  static PlaceSuggestion _suggestionFromJson(Map<String, dynamic> json) =>
      PlaceSuggestion(
        placeId: json['placeId'] as String? ?? '',
        primaryText: json['primaryText'] as String? ?? '',
        secondaryText: json['secondaryText'] as String? ?? '',
      );

  static PlaceDetails _detailsFromJson(Map<String, dynamic> json) =>
      PlaceDetails(
        placeId: json['placeId'] as String? ?? '',
        address: json['address'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        district: json['district'] as String?,
        city: json['city'] as String?,
      );
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(ref.watch(apiClientProvider)),
);
