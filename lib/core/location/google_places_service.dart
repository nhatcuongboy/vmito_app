import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';
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

class GooglePlacesService {
  GooglePlacesService({Dio? client}) : _client = client ?? Dio();

  final Dio _client;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String language,
  }) async {
    if (!AppConfig.hasGooglePlaces) {
      AppLogger.warn(
        'GooglePlacesService.autocomplete skipped: GOOGLE_PLACES_API_KEY is '
        'empty for this build (--dart-define-from-file env/*.json).',
      );
      return const [];
    }
    if (input.trim().length < 2) return const [];
    AppLogger.network(
      'GooglePlacesService.autocomplete input="$input" '
      'keyLength=${AppConfig.googlePlacesApiKey.length}',
    );
    try {
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
      AppLogger.network(
        'GooglePlacesService.autocomplete status=${response.statusCode} '
        'suggestionCount=${suggestions.length}',
      );
      return [
        for (final item in suggestions.whereType<Map<String, dynamic>>())
          if (item['placePrediction'] case final Map<String, dynamic>
              prediction)
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
    } on DioException catch (e) {
      AppLogger.error(
        'GooglePlacesService.autocomplete failed status=${e.response?.statusCode} '
        'body=${e.response?.data}',
        error: e,
      );
      rethrow;
    }
  }

  Future<PlaceDetails> details({
    required String placeId,
    required String language,
  }) async {
    Map<String, dynamic> json;
    try {
      final response = await _client.get<Map<String, dynamic>>(
        'https://places.googleapis.com/v1/places/$placeId',
        queryParameters: {'languageCode': language},
        options: _options('id,formattedAddress,location,addressComponents'),
      );
      AppLogger.network(
        'GooglePlacesService.details placeId=$placeId '
        'status=${response.statusCode}',
      );
      json = response.data ?? const <String, dynamic>{};
    } on DioException catch (e) {
      AppLogger.error(
        'GooglePlacesService.details failed placeId=$placeId '
        'status=${e.response?.statusCode} body=${e.response?.data}',
        error: e,
      );
      rethrow;
    }
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
      ..._appIdentityHeaders,
    },
  );

  // Places API (New) is called over plain HTTP, so a key restricted to this
  // app's iOS/Android identity can't detect the caller on its own — Google
  // rejects every request as an <empty> app unless we self-report it here.
  static const _bundleId = 'com.vmito.app';

  Map<String, String> get _appIdentityHeaders =>
      switch (defaultTargetPlatform) {
        TargetPlatform.iOS => {'X-Ios-Bundle-Identifier': _bundleId},
        TargetPlatform.android => {'X-Android-Package': _bundleId},
        _ => const {},
      };
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(),
);
