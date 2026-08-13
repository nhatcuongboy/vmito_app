import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/constants/api_endpoints.dart';
import 'package:vmito_app/core/network/api_client.dart';
import 'package:vmito_app/core/network/api_response.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';
import 'package:vmito_app/features/leaderboard/domain/repositories/ranking_repository.dart';

/// Ports `vmito-fe/src/lib/api/ranking.service.ts`.
class RankingRepositoryImpl implements RankingRepository {
  const RankingRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<LeaderboardPage> leaderboard({
    required LeaderboardPeriod period,
    required int page,
    required int limit,
    String? periodKey,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboard,
      queryParameters: {
        'period': period.wireValue,
        if (periodKey != null && periodKey.isNotEmpty) 'periodKey': periodKey,
        'board': 'player',
        'page': page,
        'limit': limit,
      },
    );
    return unwrap(response.data, LeaderboardPage.fromJson);
  }
}

final rankingRepositoryProvider = Provider<RankingRepository>(
  (ref) => RankingRepositoryImpl(ref.watch(apiClientProvider)),
);
