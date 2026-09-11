import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/social/data/social_service.dart';
import 'package:vmito_app/features/social/domain/club_browse_filters.dart';

class _ApiClient extends Mock implements ApiClient {}

void main() {
  test(
    'browseClubs sends the active filters as comma-separated params',
    () async {
      final client = _ApiClient();
      const query = {
        'page': 1,
        'limit': 20,
        'city': 'Hồ Chí Minh',
        'district': 'Phường 1,Phường 2',
        'levels': '3,9',
        'activeDays': '1,6',
        'activePeriods': 'morning,evening',
      };
      when(
        () => client.get<Map<String, dynamic>>(
          '/clubs',
          queryParameters: query,
        ),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: '/clubs'),
          data: const {'success': true, 'data': <dynamic>[]},
        ),
      );

      await SocialService(client).browseClubs(
        page: 1,
        filters: const ClubBrowseFilters(
          city: 'Hồ Chí Minh',
          cityIsDefault: false,
          districts: {'Phường 1', 'Phường 2'},
          levels: {9, 3},
          activeDays: {6, 1},
          activePeriods: {
            ClubActivityPeriod.evening,
            ClubActivityPeriod.morning,
          },
        ),
      );

      verify(
        () => client.get<Map<String, dynamic>>(
          '/clubs',
          queryParameters: query,
        ),
      ).called(1);
    },
  );

  test('browseClubs omits filter params and favoriteOnly when unset', () async {
    final client = _ApiClient();
    const query = {'page': 1, 'limit': 20};
    when(
      () => client.get<Map<String, dynamic>>(
        '/clubs',
        queryParameters: query,
      ),
    ).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/clubs'),
        data: const {'success': true, 'data': <dynamic>[]},
      ),
    );

    await SocialService(client).browseClubs(page: 1);

    final captured =
        verify(
              () => client.get<Map<String, dynamic>>(
                '/clubs',
                queryParameters: captureAny(named: 'queryParameters'),
              ),
            ).captured.single
            as Map<String, dynamic>;
    expect(captured.containsKey('favoriteOnly'), isFalse);
    expect(captured, query);
  });
}
