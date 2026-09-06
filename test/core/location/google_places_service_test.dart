import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/location/google_places_service.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/error_interceptor.dart';
import 'package:vmito_app/core/storage/token_storage.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  group('GooglePlacesService', () {
    test(
      'uses the backend proxy for autocomplete without a Google API key',
      () async {
        final client = _client();
        client.raw.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              expect(options.path, ApiEndpoints.placesAutocomplete);
              expect(options.data, {'input': 'Ha Noi', 'language': 'vi'});
              expect(options.headers.containsKey('X-Goog-Api-Key'), isFalse);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'success': true,
                    'data': [
                      {
                        'placeId': 'place-1',
                        'primaryText': 'Hà Nội',
                        'secondaryText': 'Việt Nam',
                      },
                    ],
                  },
                ),
              );
            },
          ),
        );
        final service = GooglePlacesService(client);

        final results = await service.autocomplete(
          input: ' Ha Noi ',
          language: 'vi',
        );

        expect(results, hasLength(1));
        expect(results.single.placeId, 'place-1');
      },
    );

    test(
      'does not request autocomplete for fewer than two characters',
      () async {
        final service = GooglePlacesService(_client());

        expect(await service.autocomplete(input: 'x', language: 'vi'), isEmpty);
      },
    );
  });
}

ApiClient _client() => buildApiClient(
  tokenStorage: TokenStorage(FakeSecureStorage()),
  errorBus: ApiErrorBus(),
  onSessionExpired: () async {},
);
