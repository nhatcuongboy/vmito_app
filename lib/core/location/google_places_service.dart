import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';

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

class GooglePlacesService {
  GooglePlacesService({Dio? client}) : _client = client ?? Dio();

  final Dio _client;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String language,
  }) async {
    if (!AppConfig.hasGooglePlaces || input.trim().length < 2) return const [];
    final response = await _client.post<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places:autocomplete',
      data: {
        'input': input.trim(),
        'languageCode': language,
        'includedRegionCodes': ['vn'],
      },
      options: _options('suggestions.placePrediction'),
    );
    final suggestions =
        response.data?['suggestions'] as List<dynamic>? ?? const [];
    return [
      for (final item in suggestions.whereType<Map<String, dynamic>>())
        if (item['placePrediction'] case final Map<String, dynamic> prediction)
          PlaceSuggestion(
            placeId: prediction['placeId'] as String? ?? '',
            primaryText:
                ((prediction['structuredFormat'] as Map?)?['mainText']
                        as Map?)?['text']
                    as String? ??
                ((prediction['text'] as Map?)?['text'] as String? ?? ''),
            secondaryText:
                ((prediction['structuredFormat'] as Map?)?['secondaryText']
                        as Map?)?['text']
                    as String? ??
                '',
          ),
    ].where((item) => item.placeId.isNotEmpty).toList(growable: false);
  }

  Future<PlaceDetails> details({
    required String placeId,
    required String language,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places/$placeId',
      queryParameters: {'languageCode': language},
      options: _options('id,formattedAddress,location,addressComponents'),
    );
    final json = response.data ?? const <String, dynamic>{};
    final components = json['addressComponents'] as List<dynamic>? ?? const [];
    String? component(Set<String> types) {
      for (final item in components.whereType<Map<String, dynamic>>()) {
        final itemTypes = (item['types'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toSet();
        if (itemTypes.intersection(types).isNotEmpty) {
          return item['longText'] as String?;
        }
      }
      return null;
    }

    final location = json['location'] as Map<String, dynamic>?;
    return PlaceDetails(
      placeId: json['id'] as String? ?? placeId,
      address: json['formattedAddress'] as String? ?? '',
      latitude: (location?['latitude'] as num?)?.toDouble(),
      longitude: (location?['longitude'] as num?)?.toDouble(),
      district: component({'administrative_area_level_2', 'sublocality'}),
      city: component({'administrative_area_level_1'}),
    );
  }

  Options _options(String fieldMask) => Options(
    headers: {
      'X-Goog-Api-Key': AppConfig.googlePlacesApiKey,
      'X-Goog-FieldMask': fieldMask,
    },
  );
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(),
);
