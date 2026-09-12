import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

abstract interface class RankingRepository {
  Future<LeaderboardPage> leaderboard({
    required LeaderboardPeriod period,
    required int page,
    required int limit,
    String? periodKey,
  });

  /// The signed-in user's rank in every period. Authenticated; current periods
  /// only.
  Future<MyLeaderboardRanks> myRanks();
}
