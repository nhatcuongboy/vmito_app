import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/features/leaderboard/data/repositories/ranking_repository_impl.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  test('sends player board query and parses an enveloped page', () async {
    final client = _MockApiClient();
    final repository = RankingRepositoryImpl(client);
    when(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.leaderboard,
        queryParameters: any(named: 'queryParameters'),
      ),
    ).thenAnswer(
      (_) async => Response(
        requestOptions: RequestOptions(),
        data: {
          'success': true,
          'data': {
            'sport': 'BADMINTON',
            'period': 'week',
            'board': 'player',
            'isCurrentPeriod': false,
            'page': 2,
            'limit': 20,
            'total': 0,
            'totalPages': 2,
            'entries': <Object>[],
          },
        },
      ),
    );

    final result = await repository.leaderboard(
      period: LeaderboardPeriod.week,
      periodKey: '2026-08-03',
      page: 2,
      limit: 20,
    );

    expect(result.page, 2);
    verify(
      () => client.get<Map<String, dynamic>>(
        ApiEndpoints.leaderboard,
        queryParameters: {
          'period': 'week',
          'periodKey': '2026-08-03',
          'board': 'player',
          'page': 2,
          'limit': 20,
        },
      ),
    ).called(1);
  });
}
