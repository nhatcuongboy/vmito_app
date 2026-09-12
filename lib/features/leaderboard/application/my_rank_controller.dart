import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/features/leaderboard/data/repositories/ranking_repository_impl.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

/// Backs the "your position" bar when the signed-in user is not inside the
/// pages already loaded. Kept separate from `leaderboardControllerProvider` so
/// a failure here can never take the board itself down.
final myLeaderboardRanksProvider = FutureProvider<MyLeaderboardRanks>(
  (ref) => ref.watch(rankingRepositoryProvider).myRanks(),
);
