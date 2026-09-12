import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which top-3 finish the user has already been congratulated for, so
/// the confetti fires once per period instead of on every visit.
abstract interface class LeaderboardCelebrationPreferences {
  Future<String?> readCelebrated();
  Future<void> writeCelebrated(String token);
}

class SharedPreferencesLeaderboardCelebrationPreferences
    implements LeaderboardCelebrationPreferences {
  SharedPreferencesLeaderboardCelebrationPreferences([
    SharedPreferencesAsync? store,
  ]) : _store = store ?? SharedPreferencesAsync();

  static const celebratedKey = 'vmito.leaderboard.celebratedTop3';
  final SharedPreferencesAsync _store;

  @override
  Future<String?> readCelebrated() => _store.getString(celebratedKey);

  @override
  Future<void> writeCelebrated(String token) =>
      _store.setString(celebratedKey, token);
}

final leaderboardCelebrationPreferencesProvider =
    Provider<LeaderboardCelebrationPreferences>(
      (ref) => SharedPreferencesLeaderboardCelebrationPreferences(),
    );
