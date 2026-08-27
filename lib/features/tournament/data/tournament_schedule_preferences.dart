import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TournamentSchedulePreferences {
  Future<bool> readShowPlayerNames();
  Future<void> writeShowPlayerNames({required bool value});
}

class SharedPreferencesTournamentSchedulePreferences
    implements TournamentSchedulePreferences {
  SharedPreferencesTournamentSchedulePreferences([
    SharedPreferencesAsync? store,
  ]) : _store = store ?? SharedPreferencesAsync();

  static const _showPlayerNamesKey = 'vmito.schedule.showPlayerNames';
  final SharedPreferencesAsync _store;

  @override
  Future<bool> readShowPlayerNames() async =>
      await _store.getBool(_showPlayerNamesKey) ?? false;

  @override
  Future<void> writeShowPlayerNames({required bool value}) =>
      _store.setBool(_showPlayerNamesKey, value);
}

final tournamentSchedulePreferencesProvider =
    Provider<TournamentSchedulePreferences>(
      (ref) => SharedPreferencesTournamentSchedulePreferences(),
    );
