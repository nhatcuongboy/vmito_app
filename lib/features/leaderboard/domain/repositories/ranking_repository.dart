import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

// The interface is intentional: controllers can be tested without HTTP.
// ignore: one_member_abstracts
abstract interface class RankingRepository {
  Future<LeaderboardPage> leaderboard({
    required LeaderboardPeriod period,
    required int page,
    required int limit,
    String? periodKey,
  });
}
