import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/session/data/session_form_service.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test(
    'getMyImages parses the account gallery page and filters invalid rows',
    () async {
      final client = _MockApiClient();
      when(
        () => client.get<dynamic>(
          ApiEndpoints.userImages,
          queryParameters: {'page': 2, 'limit': 20},
          dedup: false,
        ),
      ).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ApiEndpoints.userImages),
          data: {
            'success': true,
            'data': {
              'data': [
                {
                  'id': 'image-1',
                  'url': 'https://example.test/image.jpg',
                  'publicId': 'session/image-1',
                },
                {'id': 'invalid', 'url': '', 'publicId': ''},
              ],
              'meta': {
                'total': 21,
                'page': 2,
                'limit': 20,
                'totalPages': 2,
              },
            },
          },
        ),
      );

      final page = await SessionFormService(
        client,
      ).getMyImages(page: 2);

      expect(page.items, hasLength(1));
      expect(page.items.single.publicId, 'session/image-1');
      expect(page.total, 21);
      expect(page.page, 2);
      expect(page.totalPages, 2);
    },
  );
}
