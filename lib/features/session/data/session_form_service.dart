import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/config/app_config.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/paginated.dart';
import 'package:vmito_app/features/session/domain/session.dart';

class ExtractedSessionData {
  const ExtractedSessionData({
    this.name,
    this.sportType,
    this.description,
    this.hostName,
    this.hostPhone,
    this.startTime,
    this.endTime,
    this.maxPlayersPerCourt,
    this.requiredLevels = const [],
    this.location,
    this.venueId,
    this.venue = const {},
    this.numberOfCourts,
    this.courtNames = const [],
    this.shuttlecock,
    this.feeConfig,
  });

  factory ExtractedSessionData.fromJson(Map<String, dynamic> json) {
    final sport = json['sportType'] as String?;
    return ExtractedSessionData(
      name: json['name'] as String?,
      sportType: sport == 'PICKLEBALL'
          ? SessionSportType.pickleball
          : sport == null
          ? null
          : SessionSportType.badminton,
      description: json['description'] as String?,
      hostName: json['hostName'] as String?,
      hostPhone: json['hostPhone'] as String?,
      startTime: DateTime.tryParse(
        json['startTime'] as String? ?? '',
      )?.toLocal(),
      endTime: DateTime.tryParse(json['endTime'] as String? ?? '')?.toLocal(),
      maxPlayersPerCourt: (json['maxPlayersPerCourt'] as num?)?.toInt(),
      requiredLevels: (json['requiredLevels'] as List<dynamic>? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false),
      location: json['location'] as String?,
      venueId: json['venueId'] as String?,
      venue: (json['venue'] as Map?)?.cast<String, dynamic>() ?? const {},
      numberOfCourts: (json['numberOfCourts'] as num?)?.toInt(),
      courtNames: (json['courtNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      shuttlecock: json['shuttlecock'] as String?,
      feeConfig: (json['feeConfig'] as Map?)?.cast<String, dynamic>(),
    );
  }

  final String? name;
  final SessionSportType? sportType;
  final String? description;
  final String? hostName;
  final String? hostPhone;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? maxPlayersPerCourt;
  final List<int> requiredLevels;
  final String? location;
  final String? venueId;
  final Map<String, dynamic> venue;
  final int? numberOfCourts;
  final List<String> courtNames;
  final String? shuttlecock;
  final Map<String, dynamic>? feeConfig;
}

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

class UserImageAsset {
  const UserImageAsset({
    required this.id,
    required this.url,
    required this.publicId,
  });

  factory UserImageAsset.fromJson(Map<String, dynamic> json) => UserImageAsset(
    id: json['id'] as String? ?? '',
    url: json['url'] as String? ?? '',
    publicId: json['publicId'] as String? ?? '',
  );

  final String id;
  final String url;
  final String publicId;
}

class SessionFormService {
  const SessionFormService(this._client);

  final ApiClient _client;

  dynamic _payload(dynamic body) =>
      body is Map<String, dynamic> && body.containsKey('success')
      ? body['data']
      : body;

  Future<ExtractedSessionData> extractSession({
    required String articleContent,
    required String language,
  }) async {
    final response = await _client.post<dynamic>(
      ApiEndpoints.aiExtractSession,
      data: {'articleContent': articleContent, 'language': language},
    );
    return ExtractedSessionData.fromJson(
      (_payload(response.data) as Map).cast<String, dynamic>(),
    );
  }

  Future<({String url, String publicId})> uploadImage({
    required Uint8List bytes,
    required String filename,
  }) async {
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1920,
      minHeight: 1920,
      quality: 82,
      format: CompressFormat.jpeg,
    );
    final response = await _client.post<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: const {'category': 'SESSION_COVER'},
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

  Future<Page<UserImageAsset>> getMyImages({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get<dynamic>(
      ApiEndpoints.userImages,
      queryParameters: {'page': page, 'limit': limit},
      dedup: false,
    );
    final payload = _payload(response.data);
    if (payload is! Map) {
      return unwrapPage<UserImageAsset>(payload, UserImageAsset.fromJson);
    }
    final json = payload.cast<String, dynamic>();
    final meta = (json['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(UserImageAsset.fromJson)
        .where((item) => item.url.isNotEmpty && item.publicId.isNotEmpty)
        .toList(growable: false);
    int readInt(String key, int fallback) =>
        (meta[key] as num?)?.toInt() ??
        (json[key] as num?)?.toInt() ??
        fallback;
    return Page<UserImageAsset>(
      items: items,
      total: readInt('total', items.length),
      page: readInt('page', page),
      limit: readInt('limit', limit),
      totalPages: readInt('totalPages', 1),
    );
  }

  Future<Map<String, bool>> featureFlags() async {
    final response = await _client.get<dynamic>(ApiEndpoints.featureFlags);
    final json =
        (_payload(response.data) as Map?)?.cast<String, dynamic>() ?? {};
    return {for (final entry in json.entries) entry.key: entry.value == true};
  }

  Future<List<PlaceSuggestion>> autocompletePlaces({
    required String input,
    required String language,
  }) async {
    if (!AppConfig.hasGooglePlaces || input.trim().length < 2) return const [];
    final response = await Dio().post<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places:autocomplete',
      data: {
        'input': input.trim(),
        'languageCode': language,
        'includedRegionCodes': ['vn'],
      },
      options: Options(
        headers: {
          'X-Goog-Api-Key': AppConfig.googlePlacesApiKey,
          'X-Goog-FieldMask': 'suggestions.placePrediction',
        },
      ),
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

  Future<PlaceDetails> placeDetails({
    required String placeId,
    required String language,
  }) async {
    final response = await Dio().get<Map<String, dynamic>>(
      'https://places.googleapis.com/v1/places/$placeId',
      queryParameters: {'languageCode': language},
      options: Options(
        headers: {
          'X-Goog-Api-Key': AppConfig.googlePlacesApiKey,
          'X-Goog-FieldMask': 'id,formattedAddress,location,addressComponents',
        },
      ),
    );
    final json = response.data ?? const {};
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
}

final sessionFormServiceProvider = Provider<SessionFormService>(
  (ref) => SessionFormService(ref.watch(apiClientProvider)),
);

final sessionFeatureFlagsProvider = FutureProvider<Map<String, bool>>(
  (ref) => ref.watch(sessionFormServiceProvider).featureFlags(),
);
