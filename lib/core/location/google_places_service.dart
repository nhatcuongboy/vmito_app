import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';
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

/// Address autocomplete backed by the native Places SDK on Android and iOS.
///
/// Each platform build receives its own application-restricted key through
/// `GOOGLE_PLACES_API_KEY`; no Places credential or proxy is owned by Vmito's
/// backend.
class GooglePlacesService {
  GooglePlacesService({
    required String apiKey,
    FlutterGooglePlacesSdk? sdk,
  }) : _sdk = sdk ?? (apiKey.isEmpty ? null : FlutterGooglePlacesSdk(apiKey));

  final FlutterGooglePlacesSdk? _sdk;

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String language,
  }) async {
    final sdk = _sdk;
    final query = input.trim();
    if (sdk == null || query.length < 2) return const [];

    try {
      await _setLanguage(sdk, language);
      final response = await sdk.findAutocompletePredictions(
        query,
        countries: const ['vn'],
      );
      return [
        for (final prediction in response.predictions)
          if (prediction.placeId?.isNotEmpty ?? false)
            PlaceSuggestion(
              placeId: prediction.placeId!,
              primaryText: prediction.primaryText ?? '',
              secondaryText: prediction.secondaryText ?? '',
            ),
      ];
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
    final sdk = _sdk;
    if (sdk == null) {
      throw StateError(
        'GOOGLE_PLACES_API_KEY is missing for this platform build.',
      );
    }

    try {
      await _setLanguage(sdk, language);
      final response = await sdk.fetchPlace(
        placeId,
        fields: const [
          PlaceField.Id,
          PlaceField.FormattedAddress,
          PlaceField.AddressComponents,
          PlaceField.Location,
        ],
      );
      final place = response.place;
      if (place == null) {
        throw StateError('Places SDK returned no details for $placeId.');
      }

      final components = place.addressComponents ?? const [];
      String? component(Set<String> types) {
        for (final item in components) {
          if ((item.types ?? const []).toSet().intersection(types).isNotEmpty) {
            return item.name;
          }
        }
        return null;
      }

      return PlaceDetails(
        placeId: place.id ?? placeId,
        address: place.address ?? '',
        latitude: place.latLng?.lat,
        longitude: place.latLng?.lng,
        district: component({
          'administrative_area_level_2',
          'sublocality',
          'sublocality_level_1',
        }),
        city: component({'administrative_area_level_1'}),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.error(
        'GooglePlacesService.details failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _setLanguage(
    FlutterGooglePlacesSdk sdk,
    String language,
  ) => sdk.updateSettings(locale: Locale(language));
}

final googlePlacesServiceProvider = Provider<GooglePlacesService>(
  (ref) => GooglePlacesService(apiKey: AppConfig.googlePlacesApiKey),
);
