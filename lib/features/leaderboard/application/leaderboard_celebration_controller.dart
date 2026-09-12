import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vmito_app/core/utils/logger.dart';
import 'package:vmito_app/features/leaderboard/application/leaderboard_controller.dart';
import 'package:vmito_app/features/leaderboard/data/leaderboard_celebration_preferences.dart';
import 'package:vmito_app/features/leaderboard/domain/leaderboard.dart';

/// Only the actual podium is worth celebrating.
const celebratedTopRank = 3;

class LeaderboardCelebrationState {
  const LeaderboardCelebrationState({this.entry, this.period, this.token});

  /// The user's own top-3 entry, set only while the celebration should show.
  final LeaderboardEntry? entry;
  final LeaderboardPeriod? period;

  /// The persisted `<period>:<identity>:<rank>` gate this showing consumed.
  final String? token;

  bool get isVisible => entry != null;
}

/// Fires the top-3 celebration at most once per period, and again only when the
/// rank improves.
///
/// Diverges from web on purpose: `vmito-fe/PointsCelebration.tsx` reacts to a
/// `POINTS_AWARDED` socket event with `tierChanged`, which is a different
/// event. This one reacts to a standing on the current board.
class LeaderboardCelebrationController
    extends Notifier<LeaderboardCelebrationState> {
  @override
  LeaderboardCelebrationState build() => const LeaderboardCelebrationState();

  Future<void> evaluate(
    LeaderboardState board,
    String? currentUserId,
  ) async {
    if (state.isVisible || currentUserId == null) return;
    if (!board.hasLoaded || !board.isCurrentPeriod) return;
    final periodEnd = board.periodEnd;
    if (periodEnd == null) return;
    final entry = board.entries.firstWhereOrNull(
      (candidate) => candidate.user.id == currentUserId,
    );
    if (entry == null || entry.rank > celebratedTopRank) return;

    // `periodKey` is null for the current period, so it cannot identify one
    // week from the next. `periodEnd` — the API's exclusive upper bound — can.
    final identity =
        '${board.period.wireValue}:'
        '${board.periodKey ?? periodEnd.toIso8601String()}';
    final token = '$identity:${entry.rank}';

    final preferences = ref.read(leaderboardCelebrationPreferencesProvider);
    try {
      final stored = await preferences.readCelebrated();
      if (stored != null && _suppresses(stored, identity, entry.rank)) return;
      // Written before showing, so a kill mid-celebration cannot replay it.
      await preferences.writeCelebrated(token);
    } on Object catch (error) {
      // A broken store must not cost the user their celebration.
      AppLogger.warn('leaderboard celebration gate failed', error: error);
    }
    state = LeaderboardCelebrationState(
      entry: entry,
      period: board.period,
      token: token,
    );
  }

  void dismiss() => state = const LeaderboardCelebrationState();

  /// True when this period was already celebrated at an equal or better rank.
  /// Splits on the last `:` because the identity embeds an ISO timestamp.
  static bool _suppresses(String stored, String identity, int rank) {
    final split = stored.lastIndexOf(':');
    if (split < 0) return false;
    final storedRank = int.tryParse(stored.substring(split + 1));
    if (storedRank == null) return false;
    return stored.substring(0, split) == identity && storedRank <= rank;
  }
}

final leaderboardCelebrationControllerProvider =
    NotifierProvider<
      LeaderboardCelebrationController,
      LeaderboardCelebrationState
    >(LeaderboardCelebrationController.new);
