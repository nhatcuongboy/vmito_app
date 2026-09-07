import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/location/google_places_service.dart';

class _PlacesSdk extends Mock implements FlutterGooglePlacesSdk {}

void main() {
  group('GooglePlacesService', () {
    late _PlacesSdk sdk;
    late GooglePlacesService service;

    setUp(() {
      sdk = _PlacesSdk();
      service = GooglePlacesService(apiKey: 'test-key', sdk: sdk);
      when(
        () => sdk.updateSettings(locale: const Locale('vi')),
      ).thenAnswer((_) async {});
    });

    test('uses the native SDK and maps autocomplete predictions', () async {
      when(
        () => sdk.findAutocompletePredictions(
          'Ha Noi',
          countries: const ['vn'],
        ),
      ).thenAnswer(
        (_) async => const FindAutocompletePredictionsResponse([
          AutocompletePrediction(
            placeId: 'place-1',
            primaryText: 'Hà Nội',
            secondaryText: 'Việt Nam',
            fullText: 'Hà Nội, Việt Nam',
          ),
        ]),
      );

      final results = await service.autocomplete(
        input: ' Ha Noi ',
        language: 'vi',
      );

      expect(results, hasLength(1));
      expect(results.single.placeId, 'place-1');
      expect(results.single.primaryText, 'Hà Nội');
      expect(results.single.secondaryText, 'Việt Nam');
      verify(
        () => sdk.updateSettings(locale: const Locale('vi')),
      ).called(1);
    });

    test('maps native place details and address components', () async {
      when(
        () => sdk.fetchPlace(
          'place-1',
          fields: const [
            PlaceField.Id,
            PlaceField.FormattedAddress,
            PlaceField.AddressComponents,
            PlaceField.Location,
          ],
        ),
      ).thenAnswer(
        (_) async => FetchPlaceResponse(
          Place.fromJson({
            'id': 'place-1',
            'address': '1 Tràng Tiền, Hà Nội',
            'latLng': {'lat': 21.024, 'lng': 105.856},
            'addressComponents': [
              {
                'name': 'Hoàn Kiếm',
                'shortName': 'Hoàn Kiếm',
                'types': ['administrative_area_level_2'],
              },
              {
                'name': 'Hà Nội',
                'shortName': 'HN',
                'types': ['administrative_area_level_1'],
              },
            ],
          }),
        ),
      );

      final result = await service.details(
        placeId: 'place-1',
        language: 'vi',
      );

      expect(result.address, '1 Tràng Tiền, Hà Nội');
      expect(result.latitude, 21.024);
      expect(result.longitude, 105.856);
      expect(result.district, 'Hoàn Kiếm');
      expect(result.city, 'Hà Nội');
    });

    test('does not request autocomplete for fewer than two characters', () {
      expect(
        service.autocomplete(input: 'x', language: 'vi'),
        completion(isEmpty),
      );
      verifyNever(
        () => sdk.findAutocompletePredictions(
          any(),
          countries: any(named: 'countries'),
        ),
      );
    });

    test('degrades to no suggestions when the platform key is missing', () {
      final unconfigured = GooglePlacesService(apiKey: '');

      expect(
        unconfigured.autocomplete(input: 'Hanoi', language: 'vi'),
        completion(isEmpty),
      );
    });
  });
}
