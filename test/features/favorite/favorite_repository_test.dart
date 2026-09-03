import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/favorite/data/favorite_repository.dart';
import 'package:vmito_app/features/favorite/domain/favorite_summary.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockApiClient client;
  late FavoriteRepository repository;

  setUp(() {
    client = _MockApiClient();
    repository = FavoriteRepositoryImpl(client);
  });

  for (final type in FavoriteType.values) {
    test(
      '${type.name} uses ${type.wireValue} in favorite API requests',
      () async {
        when(
          () => client.post<dynamic>(
            ApiEndpoints.favorites,
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));
        when(
          () => client.delete<dynamic>(
            ApiEndpoints.favorite(type.wireValue, 'target-1'),
          ),
        ).thenAnswer((_) async => Response(requestOptions: RequestOptions()));

        await repository.add(type, 'target-1');
        await repository.remove(type, 'target-1');

        final body =
            verify(
                  () => client.post<dynamic>(
                    ApiEndpoints.favorites,
                    data: captureAny(named: 'data'),
                  ),
                ).captured.single
                as Map<String, dynamic>;
        expect(body, {'type': type.wireValue, 'targetId': 'target-1'});
        verify(
          () => client.delete<dynamic>(
            ApiEndpoints.favorite(type.wireValue, 'target-1'),
          ),
        ).called(1);
      },
    );
  }

  test('summary uses the typed endpoint and parses the response', () async {
    when(
      () => client.get<dynamic>(
        ApiEndpoints.favoriteSummary('VENUE', 'venue-1'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': {
            'isFavorite': true,
            'favoriteCount': 3,
            'canViewUsers': false,
          },
        },
      ),
    );

    final result = await repository.summary(FavoriteType.venue, 'venue-1');

    expect(result.isFavorite, isTrue);
    expect(result.favoriteCount, 3);
  });
}
